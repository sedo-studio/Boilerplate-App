//
//  Entitlements.swift
//
//  Observable purchase state. Injected at the root like `AppRouter` so any
//  screen can ask "is the radar unlocked?" without touching the store.
//

import SwiftUI

@MainActor
final class Entitlements: ObservableObject {
    @Published private(set) var active: Set<String> = []
    @Published private(set) var isRefreshing: Bool = false

    private let purchases: PurchasesService
    private let flags: FeatureFlags

    init(purchases: PurchasesService, flags: FeatureFlags) {
        self.purchases = purchases
        self.flags = flags
    }

    /// The radar is open to everyone when the app is built without monetization.
    var isRadarUnlocked: Bool {
        !flags.radarUnlock || active.contains(AppEntitlement.radarUnlock.rawValue)
    }

    var hasLeftBehindAlerts: Bool {
        flags.leftBehindAlerts && active.contains(AppEntitlement.leftBehindAlerts.rawValue)
    }

    func owns(_ entitlement: AppEntitlement) -> Bool {
        active.contains(entitlement.rawValue)
    }

    /// Forces a store round-trip. This broadcasts `.entitlementsDidChange`, so
    /// never call it from a handler for that notification — use `reload()`.
    func refresh() async {
        isRefreshing = true
        await purchases.refreshEntitlements()
        active = await purchases.activeEntitlements()
        isRefreshing = false
    }

    /// Re-reads cached entitlement state without asking the store to sync.
    func reload() async {
        active = await purchases.activeEntitlements()
    }

    func options(for entitlement: AppEntitlement) async -> [PurchaseOption] {
        await purchases.loadOptions(for: entitlement)
    }

    func purchase(_ option: PurchaseOption) async throws {
        try await purchases.purchase(packageIdentifier: option.id)
        active = await purchases.activeEntitlements()
    }

    func restore() async throws {
        try await purchases.restorePurchases()
        active = await purchases.activeEntitlements()
    }

    func showManageSubscriptions() async {
        await purchases.showManageSubscriptions()
        active = await purchases.activeEntitlements()
    }
}
