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

    /// Connected devices rank above measured ones, then strongest signal first.
    static func strongestFirst(_ lhs: DiscoveredDevice, _ rhs: DiscoveredDevice) -> Bool {
        if lhs.isConnected != rhs.isConnected { return lhs.isConnected }
        return (lhs.rssi ?? Int.min) > (rhs.rssi ?? Int.min)
    }
}

/// Name fragments that suggest a peripheral is a pair of headphones.
///
/// CoreBluetooth cannot tell us a device's product category, and decoding
/// Apple's proximity-pairing advertisements is undocumented and fragile, so the
/// free scan leans on names. Anything unmatched is still selectable by hand.
enum HeadphoneHeuristic {
    static let nameFragments = [
        "airpod", "beats", "buds", "headphone", "headset", "earphone",
        "earbud", "pods", "wh-", "wf-", "quietcomfort", "bose", "soundcore",
        "jabra", "jbl", "sennheiser", "momentum", "galaxy buds", "pixel buds"
    ]

    static func looksLikeHeadphones(name: String) -> Bool {
        let lowered = name.lowercased()
        return nameFragments.contains { lowered.contains($0) }
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
}
