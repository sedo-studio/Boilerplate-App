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
            appName: "Find My Headphones",
            // Must match PRODUCT_BUNDLE_IDENTIFIER in project.yml.
            bundleId: "com.francisgane.findmyheadphones",
            // Fill in once the app has an App Store listing — the review
            // prompt's fallback link needs it.
            appStoreId: "",
            featureFlags: FeatureFlags(onboarding: true, radarUnlock: true, leftBehindAlerts: true, reviewPrompt: true),
            // TODO: replace both before submitting. Apple rejects placeholder
            // legal links, and the paywalls link to them.
            legal: LegalLinks(
                privacyPolicyURL: URL(string: "https://example.com/privacy")!,
                termsURL: URL(string: "https://example.com/terms")!
            )
        )
    }
}
