//
//  BluetoothFinder.swift
//
//  The Bluetooth engine. One CBCentralManager for the whole app — the finder
//  screens and the left-behind monitor both read from this object.
//
//  What it can and cannot do, so nobody builds on a wrong assumption:
//  • It measures signal strength (RSSI), which tells you how strong the link is,
//    not which direction the headphones are in. AirPods have no U1 chip, so no
//    third-party app can draw a real compass arrow for them.
//  • It uses public CoreBluetooth only — no decoding of Apple's undocumented
//    proximity-pairing advertisements.
//

import Foundation
import CoreBluetooth

@MainActor
final class BluetoothFinder: NSObject, ObservableObject {
    static let shared = BluetoothFinder()

    // MARK: Published state

    @Published private(set) var state: FinderState = .idle
    /// Everything seen during this scan, best match first.
    @Published private(set) var candidates: [DiscoveredDevice] = []
    /// The device the user is looking for.
    @Published private(set) var trackedDevice: DiscoveredDevice?
    @Published private(set) var proximity: ProximityLevel = .far
    @Published private(set) var trend: ProximityTrend = .steady
    @Published private(set) var isTrackingProximity: Bool = false
    /// True once a real reading has arrived, so the radar can show a warm-up
    /// state instead of pretending to know something.
    @Published private(set) var hasLiveReading: Bool = false

    /// Set by `LeftBehindMonitor` when it needs the GATT link kept alive so iOS
    /// can wake the app on connect/disconnect.
    var wantsPersistentConnection: Bool = false

    // MARK: Private state

    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var smoother = RSSISmoother()
    private var scanTimeout: Task<Void, Never>?
    private var rssiPoll: Task<Void, Never>?

    #if DEBUG
    @Published private(set) var isDemoMode: Bool = false
    fileprivate var demoTask: Task<Void, Never>?
    #endif

    private let savedIdKey = "finder.device.id"
    private let savedNameKey = "finder.device.name"
    private let scanWindow: TimeInterval = 15
    /// GATT services commonly exposed by connected audio accessories, used to
    /// find peripherals already connected to this iPhone.
    private let connectedServices = [CBUUID(string: "180F"), CBUUID(string: "180A")]

    private override init() {
        super.init()
        restoreSavedDevice()
    }

    /// Rebuilds `trackedDevice` from what was saved, so background
    /// connect/disconnect events and the radar work after a cold launch,
    /// before any scan has run.
    fileprivate func restoreSavedDevice() {
        guard let id = savedDeviceId else {
            trackedDevice = nil
            return
        }
        trackedDevice = DiscoveredDevice(id: id,
                                         name: UserDefaults.standard.string(forKey: savedNameKey) ?? "",
                                         rssi: nil)
    }

    /// Devices whose name reads like headphones — what the main UI offers.
    var headphoneCandidates: [DiscoveredDevice] {
        candidates.filter { HeadphoneHeuristic.looksLikeHeadphones(name: $0.name) || $0.isConnected }
    }

    /// Everything seen, including unnamed peripherals, for the manual picker.
    var allNamedCandidates: [DiscoveredDevice] {
        candidates.filter { !$0.name.isEmpty }
    }

    // MARK: - Permission

    var authorization: CBManagerAuthorization { CBManager.authorization }
    var isAuthorized: Bool { authorization == .allowedAlways }
    var needsBluetoothPermission: Bool { authorization == .notDetermined }

    /// Creates the central manager, which is what triggers the system
    /// permission prompt. Called from onboarding so the prompt follows the
    /// explanation instead of ambushing the user on launch.
    func prepare() {
        guard central == nil else { return }
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
                // Lets iOS relaunch the app for connection events while
                // backgrounded, which is what makes left-behind alerts work.
                CBCentralManagerOptionRestoreIdentifierKey: "finder.central.restore"
            ]
        )
    }

    // MARK: - Saved device

    var savedDeviceName: String? { UserDefaults.standard.string(forKey: savedNameKey) }

    private var savedDeviceId: UUID? {
        UserDefaults.standard.string(forKey: savedIdKey).flatMap(UUID.init(uuidString:))
    }

    func select(_ device: DiscoveredDevice) {
        UserDefaults.standard.set(device.id.uuidString, forKey: savedIdKey)
        UserDefaults.standard.set(device.name, forKey: savedNameKey)
        trackedDevice = device
        state = .found(device)
    }

    func forgetDevice() {
        UserDefaults.standard.removeObject(forKey: savedIdKey)
        UserDefaults.standard.removeObject(forKey: savedNameKey)
        trackedDevice = nil
        stopProximityTracking()
        state = .idle
    }

    // MARK: - Scanning

    func startScan() {
        #if DEBUG
        if isDemoMode { runDemoScan(); return }
        #endif
        prepare()
        guard let central else { return }

        candidates = []
        resetSignal()

        switch central.state {
        case .poweredOn:
            break
        case .unauthorized:
            state = .unauthorized
            return
        case .poweredOff:
            state = .poweredOff
            return
        case .unsupported:
            state = .unsupported
            return
        default:
            // .resetting / .unknown — the delegate restarts the scan once the
            // manager settles.
            state = .scanning
            return
        }

        state = .scanning

        // A device already connected for audio never appears in a scan, so
        // check that list first. It is also the fastest path to the free
        // "found nearby" moment.
        for peripheral in central.retrieveConnectedPeripherals(withServices: connectedServices) {
            register(peripheral, rssi: nil, isConnected: true)
        }
        if let savedDeviceId, let known = central.retrievePeripherals(withIdentifiers: [savedDeviceId]).first {
            register(known, rssi: nil, isConnected: known.state == .connected)
        }
        // If they're already connected for audio they are certainly nearby, so
        // answer now instead of making the user wait out the scan window.
        if let connected = bestCandidate(), connected.isConnected {
            confirmFound(connected)
        }

        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )

        scanTimeout?.cancel()
        let window = scanWindow
        scanTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finishScanWindow()
        }
    }

    func stopScan() {
        // The radar runs its own scan. Leaving the detect screen to open it
        // fires this, and tearing the scan down would starve the radar.
        guard !isTrackingProximity else { return }

        scanTimeout?.cancel()
        scanTimeout = nil
        #if DEBUG
        if isDemoMode {
            demoTask?.cancel()
            demoTask = nil
            if case .scanning = state { state = .idle }
            return
        }
        #endif
        central?.stopScan()
        if case .scanning = state { state = .idle }
    }

    private func finishScanWindow() {
        guard case .scanning = state else { return }
        if let best = bestCandidate() {
            confirmFound(best)
        } else {
            central?.stopScan()
            state = .notFound
        }
    }

    /// The saved device if it is in range, otherwise the strongest peripheral
    /// that looks like headphones.
    private func bestCandidate() -> DiscoveredDevice? {
        if let savedDeviceId, let saved = candidates.first(where: { $0.id == savedDeviceId }) {
            return saved
        }
        return headphoneCandidates.sorted(by: DiscoveredDevice.strongestFirst).first
    }

    private func confirmFound(_ device: DiscoveredDevice) {
        trackedDevice = device
        if savedDeviceId == nil {
            select(device)
        } else {
            state = .found(device)
        }
        // The scan keeps running: the radar needs a live RSSI stream and the
        // user may walk toward the device straight from this screen.
    }

    // MARK: - Proximity tracking (radar)

    func startProximityTracking() {
        #if DEBUG
        if isDemoMode {
            isTrackingProximity = true
            startDemoFeed()
            return
        }
        #endif
        guard let device = trackedDevice else { return }
        prepare()
        guard let central else { return }

        isTrackingProximity = true
        resetSignal()

        if central.state == .poweredOn {
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            // A GATT connection gives us readRSSI, which keeps working when the
            // device stops advertising. The peripheral may not be cached yet if
            // the radar was opened straight after a cold launch.
            if let peripheral = resolvePeripheral(device.id) {
                switch peripheral.state {
                case .disconnected: central.connect(peripheral, options: nil)
                case .connected:    connectedPeripheral = peripheral
                default:            break
                }
            }
        }

        rssiPoll?.cancel()
        rssiPoll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.pollConnectedRSSI()
            }
        }
    }

    func stopProximityTracking() {
        #if DEBUG
        if isDemoMode {
            isTrackingProximity = false
            return
        }
        #endif
        isTrackingProximity = false
        rssiPoll?.cancel()
        rssiPoll = nil
        central?.stopScan()
        if let connectedPeripheral, connectedPeripheral.state == .connected, !wantsPersistentConnection {
            central?.cancelPeripheralConnection(connectedPeripheral)
        }
    }

    /// Looks a peripheral up in this session's cache, falling back to
    /// CoreBluetooth's own store for devices seen in an earlier launch.
    private func resolvePeripheral(_ id: UUID) -> CBPeripheral? {
        if let cached = peripherals[id] { return cached }
        guard let peripheral = central?.retrievePeripherals(withIdentifiers: [id]).first else { return nil }
        peripherals[id] = peripheral
        peripheral.delegate = self
        return peripheral
    }

    private func pollConnectedRSSI() {
        guard let peripheral = connectedPeripheral, peripheral.state == .connected else { return }
        peripheral.readRSSI()
    }

    // MARK: - Sample intake

    private func register(_ peripheral: CBPeripheral, rssi: Int?, isConnected: Bool, advertisedName: String? = nil) {
        peripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self

        let name = advertisedName ?? peripheral.name ?? ""
        let existing = candidates.first(where: { $0.id == peripheral.identifier })
        let device = DiscoveredDevice(id: peripheral.identifier,
                                      name: name.isEmpty ? (existing?.name ?? "") : name,
                                      rssi: rssi ?? existing.flatMap(\.rssi),
                                      isConnected: isConnected || peripheral.state == .connected)

        if let index = candidates.firstIndex(where: { $0.id == device.id }) {
            candidates[index] = device
        } else {
            candidates.append(device)
        }
        candidates.sort(by: DiscoveredDevice.strongestFirst)

        guard device.id == trackedDevice?.id || device.id == savedDeviceId else { return }
        trackedDevice = device
        if let rssi { ingestRSSI(rssi) }
    }

    /// Drops every reading taken so far, so a new scan never shows the last
    /// one's proximity while it warms up.
    fileprivate func resetSignal() {
        smoother.reset()
        hasLiveReading = false
        proximity = .far
        trend = .steady
    }

    fileprivate func ingestRSSI(_ rssi: Int) {
        smoother.add(rssi)
        guard let level = smoother.proximity else { return }
        hasLiveReading = true
        proximity = level
        trend = smoother.trend
    }
}

#if DEBUG
// MARK: - Simulator demo mode
//
// The simulator has no Bluetooth radio, so without this every finder screen is
// stuck on "Not supported" and the UI can't be reviewed. Feeds a synthetic
// signal that sweeps the whole range, so each proximity bucket and both trends
// appear within about half a minute. Never compiled into a release build.

extension BluetoothFinder {
    private static let demoDeviceID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    func setDemoMode(_ enabled: Bool) {
        isDemoMode = enabled
        demoTask?.cancel()
        demoTask = nil
        resetSignal()

        if enabled {
            // Never persisted, so the user's real saved device survives.
            let device = DiscoveredDevice(id: Self.demoDeviceID,
                                          name: "Demo AirPods Pro",
                                          rssi: -72)
            candidates = [device]
            trackedDevice = device
        } else {
            candidates = []
            restoreSavedDevice()
        }
        state = .idle
    }

    fileprivate func runDemoScan() {
        demoTask?.cancel()
        demoTask = nil
        resetSignal()
        state = .scanning

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, self.isDemoMode, case .scanning = self.state else { return }
            if let device = self.trackedDevice { self.state = .found(device) }
            self.startDemoFeed()
        }
    }

    fileprivate func startDemoFeed() {
        guard demoTask == nil else { return }
        demoTask = Task { [weak self] in
            var tick = 0.0
            while !Task.isCancelled {
                guard let self, self.isDemoMode else { return }
                // Sweeps roughly -92…-44 dBm, so the dial travels the full
                // cool → warm ramp and back.
                self.ingestRSSI(Int(-68.0 + 24.0 * sin(tick)))
                tick += 0.18
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}
#endif

// MARK: - CBCentralManagerDelegate

extension BluetoothFinder: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let managerState = central.state
        Task { @MainActor [weak self] in
            self?.handleManagerState(managerState)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let reading = RSSI.intValue
        Task { @MainActor [weak self] in
            self?.register(peripheral, rssi: reading, isConnected: false, advertisedName: advertisedName)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            self?.handleConnect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor [weak self] in
            self?.handleDisconnect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor [weak self] in
            // Advertisement RSSI still feeds the radar, so a failed GATT
            // connection is not fatal.
            self?.clearConnection(for: peripheral.identifier)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    willRestoreState dict: [String: Any]) {
        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        Task { @MainActor [weak self] in
            guard let self else { return }
            for peripheral in restored {
                self.peripherals[peripheral.identifier] = peripheral
                peripheral.delegate = self
                if peripheral.state == .connected { self.connectedPeripheral = peripheral }
            }
        }
    }

    private func handleManagerState(_ managerState: CBManagerState) {
        switch managerState {
        case .poweredOn:
            if case .scanning = state { startScan() }
            if wantsPersistentConnection { reconnectTrackedDevice() }
        case .unauthorized:
            state = .unauthorized
        case .poweredOff:
            state = .poweredOff
        case .unsupported:
            state = .unsupported
        default:
            break
        }
    }

    private func clearConnection(for id: UUID) {
        if connectedPeripheral?.identifier == id { connectedPeripheral = nil }
    }

    private func handleConnect(_ peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.readRSSI()
        guard peripheral.identifier == trackedDevice?.id || peripheral.identifier == savedDeviceId else { return }
        NotificationCenter.default.post(
            name: .headphonesDidConnect,
            object: nil,
            userInfo: [
                HeadphoneEventKey.deviceId: peripheral.identifier.uuidString,
                HeadphoneEventKey.deviceName: peripheral.name ?? trackedDevice?.name ?? ""
            ]
        )
    }

    private func handleDisconnect(_ peripheral: CBPeripheral) {
        clearConnection(for: peripheral.identifier)
        guard peripheral.identifier == trackedDevice?.id || peripheral.identifier == savedDeviceId else { return }

        NotificationCenter.default.post(
            name: .headphonesDidDisconnect,
            object: nil,
            userInfo: [
                HeadphoneEventKey.deviceId: peripheral.identifier.uuidString,
                HeadphoneEventKey.deviceName: peripheral.name ?? trackedDevice?.name ?? ""
            ]
        )

        // Re-arm the pending connection. iOS completes it whenever the device
        // is back in range, even in the background, which is how the next
        // disconnect gets noticed too.
        if wantsPersistentConnection {
            central?.connect(peripheral, options: nil)
        }
    }

    /// Arms the pending connection the left-behind monitor relies on.
    func reconnectTrackedDevice() {
        prepare()
        guard let central, central.state == .poweredOn, let id = savedDeviceId else { return }
        guard let peripheral = resolvePeripheral(id) else { return }
        switch peripheral.state {
        case .disconnected:
            central.connect(peripheral, options: nil)
        case .connected:
            connectedPeripheral = peripheral
        default:
            break
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothFinder: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        let identifier = peripheral.identifier
        let reading = RSSI.intValue
        Task { @MainActor [weak self] in
            guard let self, identifier == self.trackedDevice?.id else { return }
            self.ingestRSSI(reading)
        }
    }
}
