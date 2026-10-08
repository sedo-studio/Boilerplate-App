//
//  StoreKitStore.swift
//
//  A direct line to Apple's store, used when RevenueCat cannot serve products.
//
//  RevenueCat stays the primary store: it owns the entitlement mapping, the
//  receipts and the reporting. But asking it for products is a network call to
//  a third party, and when that call comes back empty the app has nothing to
//  sell and no way to explain itself — which is how a paywall ends up showing
//  a price above a button that cannot work.
//
//  StoreKit talks to Apple directly, so this keeps the purchase path alive
//  when RevenueCat is unreachable. Entitlements bought this way are recognised
//  from `Transaction.currentEntitlements`, so access does not depend on a
//  RevenueCat round-trip either.
//

import Foundation
import StoreKit

enum StoreKitStore {

    /// What Apple says this entitlement costs, asked directly.
    static func options(for entitlement: AppEntitlement) async -> [PurchaseOption] {
        do {
            let products = try await Product.products(for: [entitlement.productIdentifier])
            return products.map(option(from:))
        } catch {
            AppLogger.log("[StoreKit] Product lookup failed: \(error.localizedDescription)", level: .error)
            return []
        }
    }

    /// Buys a product by its App Store identifier.
    static func purchase(productIdentifier: String) async throws {
        let products = try await Product.products(for: [productIdentifier])
        guard let product = products.first else {
            throw PurchaseFriendlyError.unknown(String(localized: "paywall.error.unavailable"))
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            // An unverified transaction is Apple telling us the receipt does
            // not check out. Treat it as a failure rather than granting access.
            guard case .verified(let transaction) = verification else {
                throw PurchaseFriendlyError.unknown(String(localized: "paywall.error.unverified"))
            }
            await transaction.finish()
        case .userCancelled:
            throw PurchaseFriendlyError.cancelled
        case .pending:
            // Ask to Buy, or a payment awaiting approval. Not a failure.
            throw PurchaseFriendlyError.unknown(String(localized: "paywall.error.pending"))
        @unknown default:
            throw PurchaseFriendlyError.unknown(String(localized: "paywall.error.unavailable"))
        }
    }

    /// Entitlement identifiers Apple says this Apple ID currently owns.
    static func ownedEntitlements() async -> Set<String> {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  let entitlement = AppEntitlement.forProduct(transaction.productID)
            else { continue }
            owned.insert(entitlement.rawValue)
        }
        return owned
    }

    /// Replays past purchases through StoreKit, for Restore.
    static func restore() async throws {
        try await AppStore.sync()
    }

    // MARK: - Helpers

    private static func option(from product: Product) -> PurchaseOption {
        PurchaseOption(id: product.id,
                       displayName: product.displayName,
                       price: product.displayPrice,
                       periodText: periodText(for: product),
                       hasFreeTrial: product.subscription?.introductoryOffer?.paymentMode == .freeTrial)
    }

    private static func periodText(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return String(localized: "paywall.period.onetime")
        }
        switch period.unit {
        case .day:   return period.value == 7 ? String(localized: "paywall.period.week") : String(localized: "paywall.period.day")
        case .week:  return String(localized: "paywall.period.week")
        case .month: return String(localized: "paywall.period.month")
        case .year:  return String(localized: "paywall.period.year")
        @unknown default: return ""
        }
    }
}
