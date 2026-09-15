//
//  PurchasesService.swift
//

import Foundation

/// The two things this app sells. They are deliberately independent: buying the
/// radar never grants alerts, and subscribing to alerts never grants the radar.
public enum AppEntitlement: String, CaseIterable, Sendable {
    /// Non-consumable, one-time purchase. Unlocks the radar/proximity screen.
    case radarUnlock = "radar_unlock"
    /// Auto-renewing subscription. Unlocks proactive "left behind" alerts.
    case leftBehindAlerts = "left_behind_alerts"

    /// RevenueCat offering that sells this entitlement. Each entitlement gets
    /// its own offering so the two paywalls never show each other's products.
    public var offeringIdentifier: String { rawValue }
}

public protocol PurchasesService: Sendable {
    func configure()
    /// Entitlement identifiers the customer currently owns.
    func activeEntitlements() async -> Set<String>
    /// Re-reads entitlements from the store and broadcasts `.entitlementsDidChange`.
    func refreshEntitlements() async
    func restorePurchases() async throws
    /// Products that grant `entitlement`, newest offering first.
    func loadOptions(for entitlement: AppEntitlement) async -> [PurchaseOption]
    func purchase(packageIdentifier: String) async throws
    func showManageSubscriptions() async
}

// MARK: - Models

public struct PurchaseOption: Identifiable, Sendable, Equatable {
    public let id: String            // RevenueCat package identifier
    public let displayName: String   // "Lifetime", "Monthly"
    public let price: String         // localized, e.g. "$9.99"
    public let periodText: String    // "one-time", "per month"
    public let hasFreeTrial: Bool

    public init(id: String, displayName: String, price: String, periodText: String, hasFreeTrial: Bool) {
        self.id = id
        self.displayName = displayName
        self.price = price
        self.periodText = periodText
        self.hasFreeTrial = hasFreeTrial
    }
}

// MARK: - Local stub (no RevenueCat SDK, or no API key)

/// Keeps every screen reachable without a store connection.
///
/// Purchases only "succeed" in DEBUG builds — a release build with a missing
/// RevenueCat key grants nothing rather than silently giving the app away.
public struct LocalPurchasesService: PurchasesService {
    private let defaultsKey = "purchases.local.entitlements"

    public init() {}

    public func configure() {
        AppLogger.log("[Purchases] Local stub active — set revenueCatAPIKey in Secrets.swift for real purchases.", level: .warning)
    }

    public func activeEntitlements() async -> Set<String> {
        #if DEBUG
        let stored = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        return Set(stored)
        #else
        return []
        #endif
    }

    public func refreshEntitlements() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .entitlementsDidChange, object: nil)
        }
    }

    public func restorePurchases() async throws {
        await refreshEntitlements()
    }

    public func loadOptions(for entitlement: AppEntitlement) async -> [PurchaseOption] {
        switch entitlement {
        case .radarUnlock:
            return [PurchaseOption(id: "radar_unlock_lifetime",
                                   displayName: String(localized: "paywall.radar.plan.name"),
                                   price: "$9.99",
                                   periodText: String(localized: "paywall.radar.plan.period"),
                                   hasFreeTrial: false)]
        case .leftBehindAlerts:
            return [PurchaseOption(id: "left_behind_monthly",
                                   displayName: String(localized: "paywall.alerts.plan.name"),
                                   price: "$4.99",
                                   periodText: String(localized: "paywall.alerts.plan.period"),
                                   hasFreeTrial: false)]
        }
    }

    public func purchase(packageIdentifier: String) async throws {
        #if DEBUG
        let entitlement: AppEntitlement = packageIdentifier.hasPrefix("radar") ? .radarUnlock : .leftBehindAlerts
        var stored = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
        stored.insert(entitlement.rawValue)
        UserDefaults.standard.set(Array(stored), forKey: defaultsKey)
        await refreshEntitlements()
        #else
        throw PurchaseFriendlyError.unknown("The store is not configured.")
        #endif
    }

    public func showManageSubscriptions() async {}

    #if DEBUG
    /// Clears locally granted entitlements so the paywalls can be retested.
    public func resetLocalPurchases() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
    #endif
}
