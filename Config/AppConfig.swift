//
//  AppConfig.swift
//  __APP_NAME__
//

import Foundation
import SwiftUI

public struct Branding: Codable, Sendable {
    public var primaryColorHex: String
    public var accentColorHex: String
    public init(primaryColorHex: String, accentColorHex: String) {
        self.primaryColorHex = primaryColorHex
        self.accentColorHex = accentColorHex
    }
}

public struct LegalLinks: Codable, Sendable {
    public var privacyPolicyURL: URL
    public var termsURL: URL
}

public struct AppConfig: Codable, Sendable {
    public var appName: String
    public var bundleId: String
    /// Numeric App Store id, used to build the "write a review" link.
    public var appStoreId: String
    public var branding: Branding
    public var featureFlags: FeatureFlags
    public var legal: LegalLinks

    public init(
        appName: String,
        bundleId: String,
        appStoreId: String,
        branding: Branding,
        featureFlags: FeatureFlags,
        legal: LegalLinks
    ) {
        self.appName = appName
        self.bundleId = bundleId
        self.appStoreId = appStoreId
        self.branding = branding
        self.featureFlags = featureFlags
        self.legal = legal
    }
}

public extension AppConfig {
    static var `default`: AppConfig {
        AppConfig(
            appName: "__APP_NAME__",
            bundleId: "__BUNDLE_ID__",
            appStoreId: "__TESTFLIGHT_APP_ID__",
            branding: Branding(
                primaryColorHex: "__PRIMARY_COLOR__",
                accentColorHex: "__ACCENT_COLOR__"
            ),
            featureFlags: FeatureFlags(onboarding: true, radarUnlock: true, leftBehindAlerts: true, reviewPrompt: true),
            legal: LegalLinks(
                privacyPolicyURL: URL(string: "__PRIVACY_URL__") ?? URL(string: "https://example.com/privacy")!,
                termsURL: URL(string: "__TERMS_URL__") ?? URL(string: "https://example.com/terms")!
            )
        )
    }
}
