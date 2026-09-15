//
//  DIContainer.swift
//

import Foundation

public struct DIContainer: Sendable {
    public var config: AppConfig
    public var purchasesService: PurchasesService
    public var analytics: AnalyticsService

    public init(config: AppConfig,
                purchasesService: PurchasesService,
                analytics: AnalyticsService) {
        self.config = config
        self.purchasesService = purchasesService
        self.analytics = analytics
    }
}

public extension DIContainer {
    static func makeDefault(config: AppConfig = .default) -> DIContainer {
        let purchases: PurchasesService
        #if canImport(RevenueCat)
        if Secrets.revenueCatAPIKey.isEmpty {
            purchases = LocalPurchasesService()
        } else {
            purchases = RevenueCatPurchasesService(apiKey: Secrets.revenueCatAPIKey)
        }
        #else
        purchases = LocalPurchasesService()
        AppLogger.log("[Purchases] RevenueCat SDK not linked — add the package to enable purchases.", level: .warning)
        #endif

        let analytics: AnalyticsService
        #if canImport(TelemetryDeck) || canImport(TelemetryClient)
        if Secrets.telemetryDeckAppID.isEmpty {
            analytics = NoopAnalyticsService()
            AppLogger.log("[Noop] TelemetryDeck app ID is empty — analytics events are not being sent.", level: .warning)
        } else {
            analytics = TelemetryDeckAnalyticsService(appID: Secrets.telemetryDeckAppID)
        }
        #else
        analytics = NoopAnalyticsService()
        AppLogger.log("[Noop] TelemetryDeck SDK not linked — analytics disabled.", level: .warning)
        #endif

        return DIContainer(config: config, purchasesService: purchases, analytics: analytics)
    }
}

import SwiftUI

private struct DIKey: EnvironmentKey {
    static let defaultValue: DIContainer = .makeDefault()
}

public extension EnvironmentValues {
    var container: DIContainer {
        get { self[DIKey.self] }
        set { self[DIKey.self] = newValue }
    }
}

public extension View {
    func inject(_ container: DIContainer) -> some View { environment(\.container, container) }
}
