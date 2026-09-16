//
//  FinderModels.swift
//
//  Value types behind the finder. Everything here is pure logic so it can be
//  unit-tested without CoreBluetooth or a device.
//

import Foundation

// MARK: - Device

/// A Bluetooth peripheral that could be the user's headphones.
struct DiscoveredDevice: Identifiable, Equatable, Sendable {
    let id: UUID              // CBPeripheral.identifier — stable per device, per app install
    var name: String
    /// dBm, negative, closer to 0 is stronger. `nil` when the device is known
    /// but has not been measured yet (already connected for audio, or restored
    /// from a previous session) — never a stand-in value.
    var rssi: Int?
    var lastSeen: Date
    var isConnected: Bool

    init(id: UUID, name: String, rssi: Int?, lastSeen: Date = Date(), isConnected: Bool = false) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.lastSeen = lastSeen
        self.isConnected = isConnected
    }

    /// Whether there is actual evidence the device is within range.
    ///
    /// Knowing *about* a device is not the same as hearing it.
    /// `retrievePeripherals(withIdentifiers:)` returns a peripheral for any
    /// identifier CoreBluetooth remembers — switched off, flat, or three miles
    /// away — so a reading or a live connection is the only evidence of
    /// presence there is. Nothing else counts.
    var isPresent: Bool { rssi != nil || isConnected }

    /// Measurable devices rank first, then strongest signal, then connected.
    ///
    /// Measurability beats connectedness on purpose. A device connected for
    /// audio is certainly nearby, but if it reports no signal it is useless to
    /// the radar — and the same headphones are usually also present as a
    /// separate advertiser that *can* be measured. Rank that one higher and
    /// both screens work.
    static func strongestFirst(_ lhs: DiscoveredDevice, _ rhs: DiscoveredDevice) -> Bool {
        switch (lhs.rssi, rhs.rssi) {
        case let (left?, right?): return left > right
        case (nil, _?): return false
        case (_?, nil): return true
        case (nil, nil): return lhs.isConnected && !rhs.isConnected
        }
    }
}

/// Name fragments that suggest a peripheral is a pair of headphones.
///
/// CoreBluetooth cannot tell us a device's product category, and decoding
/// Apple's proximity-pairing advertisements is undocumented and fragile, so the
/// free scan leans on names. Anything unmatched is still selectable by hand.
enum HeadphoneHeuristic {
    /// What a scan should report as found: the saved device when it is
    /// actually present, otherwise the strongest present headphones.
    ///
    /// Everything here hinges on `isPresent`. Reporting "Found nearby" for a
    /// device we have merely heard *of* is the over-promising this app exists
    /// not to do, and it is the easiest mistake to make, because CoreBluetooth
    /// will happily hand back a peripheral for headphones that are switched
    /// off in another country.
    static func bestMatch(in candidates: [DiscoveredDevice],
                          savedId: UUID?) -> DiscoveredDevice? {
        let present = candidates.filter(\.isPresent)
        if let savedId, let saved = present.first(where: { $0.id == savedId }) {
            return saved
        }
        return present
            .filter { looksLikeHeadphones(name: $0.name) || $0.isConnected }
            .sorted(by: DiscoveredDevice.strongestFirst)
            .first
    }

    /// Advertisements are gathered for this long before a device we were never
    /// told about is allowed to end the scan early.
    static let earlySettle: TimeInterval = 2.5
    /// Strong enough to be in this room rather than through a wall.
    static let earlyRSSI = -70

    /// Whether a candidate is a good enough answer to stop waiting out the
    /// scan window and tell the user now.
    ///
    /// The window exists to let a weak or crowded field settle. Sitting
    /// through it while the user's own headphones shout from the next cushion
    /// spends fifteen seconds to say what was known in one — and this free
    /// moment is what has to earn the paid radar.
    static func canConfirmEarly(_ device: DiscoveredDevice,
                                savedId: UUID?,
                                savedName: String?,
                                elapsed: TimeInterval) -> Bool {
        guard let rssi = device.rssi else { return false }

        // The remembered device is unambiguous: the user already told us this
        // is the one, so any reading from it is enough. Matched by name as
        // well as id, because the handle that reports a signal is often not
        // the handle that was saved.
        if device.id == savedId || isSameDevice(device.name, savedName ?? "") { return true }

        // Anything else has to be both strong and given a moment for the rest
        // of the room to speak up.
        return elapsed >= earlySettle
            && rssi >= earlyRSSI
            && looksLikeHeadphones(name: device.name)
    }

    static let nameFragments = [
        "airpod", "beats", "buds", "headphone", "headset", "earphone",
        "earbud", "pods", "wh-", "wf-", "quietcomfort", "bose", "soundcore",
        "jabra", "jbl", "sennheiser", "momentum", "galaxy buds", "pixel buds"
    ]

    static func looksLikeHeadphones(name: String) -> Bool {
        let lowered = name.lowercased()
        return nameFragments.contains { lowered.contains($0) }
    }

    /// One pair of headphones often shows up twice: once as the classic audio
    /// link and once as a BLE advertiser whose name carries an "LE-" prefix
    /// (Bose, Sony and JBL all do this). They are separate CBPeripherals with
    /// separate identifiers, and only the advertiser reports a signal — so the
    /// names have to be matched to know they are the same device.
    static func normalisedName(_ name: String) -> String {
        var value = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["le-", "le_", "le "] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            break
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isSameDevice(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalisedName(lhs)
        return !left.isEmpty && left == normalisedName(rhs)
    }
}

// MARK: - Proximity

/// Coarse proximity buckets derived from signal strength.
///
/// Deliberately coarse. RSSI swings several dBm from a head turn, so anything
/// finer than this would be a number we cannot stand behind.
enum ProximityLevel: Int, CaseIterable, Sendable, Comparable {
    case far = 0
    case nearby = 1
    case close = 2
    case veryClose = 3

    init(rssi: Double) {
        switch rssi {
        case (-55)...:      self = .veryClose
        case (-70)..<(-55): self = .close
        case (-85)..<(-70): self = .nearby
        default:            self = .far
        }
    }

    static func < (lhs: ProximityLevel, rhs: ProximityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var titleKey: String {
        switch self {
        case .veryClose: return "radar.proximity.veryclose"
        case .close:     return "radar.proximity.close"
        case .nearby:    return "radar.proximity.nearby"
        case .far:       return "radar.proximity.far"
        }
    }

    var detailKey: String {
        switch self {
        case .veryClose: return "radar.proximity.veryclose.detail"
        case .close:     return "radar.proximity.close.detail"
        case .nearby:    return "radar.proximity.nearby.detail"
        case .far:       return "radar.proximity.far.detail"
        }
    }

    /// 0 (far) → 1 (very close). Drives the radar's ring size and pulse rate.
    var intensity: Double {
        switch self {
        case .far:       return 0.2
        case .nearby:    return 0.45
        case .close:     return 0.7
        case .veryClose: return 1.0
        }
    }

    /// Analytics-friendly, stable identifier.
    var analyticsValue: String {
        switch self {
        case .veryClose: return "very_close"
        case .close:     return "close"
        case .nearby:    return "nearby"
        case .far:       return "far"
        }
    }
}

/// Where a reading came from. The two paths behave very differently: a GATT
/// connection keeps working when the device stops advertising, while
/// advertisement readings need the device to still be broadcasting.
enum SignalSource: String, Sendable {
    case advertisement
    case connection
    case demo
}

/// Which way the signal is moving — the honest version of a compass arrow.
enum ProximityTrend: Sendable, Equatable {
    case warmer
    case colder
    case steady

    var titleKey: String {
        switch self {
        case .warmer: return "radar.trend.warmer"
        case .colder: return "radar.trend.colder"
        case .steady: return "radar.trend.steady"
        }
    }

}

// MARK: - Smoothing

/// Turns a noisy RSSI stream into a stable level plus a warmer/colder trend.
///
/// Two exponential moving averages: a fast one for the current reading and a
/// slow one to compare it against. When the fast average pulls away from the
/// slow one by more than `trendThreshold` dBm, the user is moving.
struct RSSISmoother: Sendable {
    let fastFactor: Double
    let slowFactor: Double
    let trendThreshold: Double

    private(set) var fast: Double?
    private(set) var slow: Double?
    private(set) var sampleCount: Int = 0

    init(fastFactor: Double = 0.35, slowFactor: Double = 0.08, trendThreshold: Double = 2.0) {
        self.fastFactor = fastFactor
        self.slowFactor = slowFactor
        self.trendThreshold = trendThreshold
    }

    mutating func add(_ rssi: Int) {
        let value = Double(rssi)
        // Readings of 127 mean "unavailable" in CoreBluetooth; anything
        // non-negative is not a usable measurement.
        guard value < 0 else { return }
        sampleCount += 1
        fast = fast.map { $0 + fastFactor * (value - $0) } ?? value
        slow = slow.map { $0 + slowFactor * (value - $0) } ?? value
    }

    mutating func reset() {
        fast = nil
        slow = nil
        sampleCount = 0
    }

    var smoothedRSSI: Double? { fast }

    var proximity: ProximityLevel? {
        fast.map(ProximityLevel.init(rssi:))
    }

    /// Needs a few samples before it will call a direction — otherwise the
    /// first reading always reads as a dramatic move.
    var trend: ProximityTrend {
        guard sampleCount >= 4, let fast, let slow else { return .steady }
        let delta = fast - slow
        if delta > trendThreshold { return .warmer }
        if delta < -trendThreshold { return .colder }
        return .steady
    }
}

// MARK: - Finder state

enum FinderState: Equatable {
    case idle
    case unsupported
    case unauthorized
    case poweredOff
    case scanning
    case found(DiscoveredDevice)
    case notFound
    /// The user confirmed they physically have the headphones. Lives here
    /// rather than in a view's local state because both the finder and the
    /// radar can end a hunt, and the radar hands back to the finder.
    case recovered
}
