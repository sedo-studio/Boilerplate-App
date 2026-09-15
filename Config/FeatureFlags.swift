//
//  FeatureFlags.swift
//

import Foundation

/// Build-time switches for the optional parts of the app. The core finder
/// (scan → "found nearby") is never flagged — it is the product.
public struct FeatureFlags: Codable, Sendable {
    /// Show the first-run onboarding (what the app does + Bluetooth rationale).
    public var onboarding: Bool
    /// Sell the radar screen as a one-time unlock (`AppEntitlement.radarUnlock`).
    /// When `false` the radar is free for everyone — useful for internal builds
    /// and for App Review screenshots.
    public var radarUnlock: Bool
    /// Enable the "left behind" alerts feature (`Modules/LeftBehind`) and its
    /// subscription (`AppEntitlement.leftBehindAlerts`).
    public var leftBehindAlerts: Bool
    /// Ask for an App Store review after a successful find (`Modules/Review`).
    public var reviewPrompt: Bool

    public init(
        onboarding: Bool = true,
        radarUnlock: Bool = true,
        leftBehindAlerts: Bool = true,
        reviewPrompt: Bool = true
    ) {
        self.onboarding = onboarding
        self.radarUnlock = radarUnlock
        self.leftBehindAlerts = leftBehindAlerts
        self.reviewPrompt = reviewPrompt
    }
}

public extension FeatureFlags {
    static var `default`: FeatureFlags { FeatureFlags() }
}
