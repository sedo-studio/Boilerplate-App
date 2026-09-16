//
//  AppConfig.swift
//  Find My Headphones
//

import Foundation
import SwiftUI

public struct LegalLinks: Codable, Sendable {
    public var privacyPolicyURL: URL
    public var termsURL: URL
}

public struct AppConfig: Codable, Sendable {
    public var appName: String
    public var bundleId: String
    /// Numeric App Store id, used to build the "write a review" link.
    public var appStoreId: String
    public var featureFlags: FeatureFlags
    public var legal: LegalLinks

    public init(
        appName: String,
        bundleId: String,
        appStoreId: String,
        featureFlags: FeatureFlags,
        legal: LegalLinks
    ) {
        self.appName = appName
        self.bundleId = bundleId
        self.appStoreId = appStoreId
        self.featureFlags = featureFlags
        self.legal = legal
    }
}

public extension AppConfig {
    static var `default`: AppConfig {
        AppConfig(
            // The App Store listing name. The bundle id predates it and does
            // not have to match — it is never shown to anyone.
            appName: "Headphone Finder",
            // Must match PRODUCT_BUNDLE_IDENTIFIER in project.yml.
            bundleId: "com.sedostudio.findmyheadphones",
            // App Store Connect's id for the listing, from its URL. The review
            // prompt's fallback link needs it.
            appStoreId: "6812735564",
            featureFlags: FeatureFlags(onboarding: true, radarUnlock: true, leftBehindAlerts: true, reviewPrompt: true),
            // Both must stay publicly reachable without a login — Apple
            // checks the privacy URL at review, and Settings and the paywalls
            // link to them.
            legal: LegalLinks(
                privacyPolicyURL: URL(string: "https://sedo-studio.com/headphone-finder/privacy")!,
                termsURL: URL(string: "https://sedo-studio.com/headphone-finder/terms")!
            )
        )
    }
}
