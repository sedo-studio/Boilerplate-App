//
//  LeftBehindMonitor.swift
//
//  "You walked off without your headphones." Watches the Bluetooth link to the
//  tracked device and, when it drops and stays dropped, sends a notification.
//
//  How the detection works, and where it is honest about its limits:
//  • A disconnect is the trigger. The app keeps a pending CoreBluetooth
//    connection open so iOS wakes it for connect/disconnect events in the
//    background (requires the `bluetooth-central` background mode).
//  • A disconnect alone is not proof the user walked away — putting AirPods in
//    the case looks identical. So the alert is scheduled after a grace period
//    and cancelled if the headphones come back, and it is rate-limited so a
//    flapping link cannot spam anyone.
//

import Foundation
import SwiftUI

@MainActor
final class LeftBehindMonitor: ObservableObject {
    static let shared = LeftBehindMonitor()

    /// User opt-in. Requires the subscription entitlement to take effect.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            applyState()
        }
    }
    @Published private(set) var isEntitled: Bool = false
    @Published private(set) var lastAlertAt: Date?

    private let enabledKey = "leftbehind.enabled"
    private let alertIdentifier = "leftbehind.alert"
    /// How long the headphones must stay disconnected before we say anything.
    private let graceSeconds: TimeInterval = 90
    /// Never alert more than once per this window.
    private let minimumInterval: TimeInterval = 10 * 60

    private var observers: [NSObjectProtocol] = []
    private var analytics: AnalyticsService?

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// True while the monitor needs the Bluetooth link kept alive.
    var isActive: Bool { isEnabled && isEntitled }

    // MARK: - Lifecycle

    func start(entitled: Bool, analytics: AnalyticsService) {
        self.analytics = analytics
        isEntitled = entitled
        guard observers.isEmpty else {
            applyState()
            return
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .headphonesDidDisconnect, object: nil, queue: .main) { [weak self] note in
            let name = note.userInfo?[HeadphoneEventKey.deviceName] as? String
            Task { @MainActor in self?.handleDisconnect(deviceName: name) }
        })
        observers.append(center.addObserver(forName: .headphonesDidConnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleConnect() }
        })
        applyState()
    }

    /// Called whenever entitlements change so a lapsed subscription stops
    /// delivering alerts without the user having to do anything.
    func updateEntitlement(_ entitled: Bool) {
        isEntitled = entitled
        applyState()
    }

    private func applyState() {
        let finder = BluetoothFinder.shared
        finder.wantsPersistentConnection = isActive
        if isActive {
            finder.reconnectTrackedDevice()
        } else {
            ReminderScheduler.shared.cancel(id: alertIdentifier)
        }
    }

    // MARK: - Events

    private func handleDisconnect(deviceName: String?) {
        guard isActive else { return }
        if let lastAlertAt, Date().timeIntervalSince(lastAlertAt) < minimumInterval { return }

        let fallbackName = BluetoothFinder.shared.savedDeviceName ?? String(localized: "finder.device.unknown")
        let name = (deviceName?.isEmpty == false) ? deviceName! : fallbackName
        let identifier = alertIdentifier
        let delay = graceSeconds

        Task {
            await ReminderScheduler.shared.schedule(
                id: identifier,
                title: String(localized: "alerts.leftbehind.notification.title"),
                body: String(localized: "alerts.leftbehind.notification.body \(name)"),
                after: delay
            )
        }
        lastAlertAt = Date()
        analytics?.track(AnalyticsEvent.leftBehindAlertSent)
    }

    private func handleConnect() {
        // They came back before the grace period elapsed — nothing was left behind.
        ReminderScheduler.shared.cancel(id: alertIdentifier)
        lastAlertAt = nil
    }

    // MARK: - Opt-in

    /// Turns the feature on, asking for notification permission first.
    /// Returns false when permission was refused.
    @discardableResult
    func enable() async -> Bool {
        await ReminderScheduler.shared.refresh()
        if !ReminderScheduler.shared.isAuthorized {
            let granted = await ReminderScheduler.shared.requestAuthorization()
            guard granted else { return false }
        }
        isEnabled = true
        analytics?.track(AnalyticsEvent.leftBehindEnabled)
        return true
    }

    func disable() {
        isEnabled = false
    }
}
