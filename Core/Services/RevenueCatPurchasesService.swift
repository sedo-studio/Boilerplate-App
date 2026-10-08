//
//  RevenueCatPurchasesService.swift
//

import Foundation

#if canImport(RevenueCat)
import RevenueCat

/// Remembers the packages a paywall was drawn from.
///
/// Without this, buying re-fetches every offering from RevenueCat just to find
/// the package the paywall already had — a second network call, at the worst
/// possible moment, that can fail on its own and leave the user staring at an
/// error after tapping Buy.
private actor PackageCache {
    private var packages: [String: Package] = [:]

    func store(_ list: [Package]) {
        for package in list { packages[package.identifier] = package }
    }

    func package(for identifier: String) -> Package? { packages[identifier] }
}

struct RevenueCatPurchasesService: PurchasesService {
    private let apiKey: String
    private let cache = PackageCache()

    init(apiKey: String) { self.apiKey = apiKey }

    func configure() {
        guard !apiKey.isEmpty else { return }
        let config = Configuration
            .builder(withAPIKey: apiKey)
            .with(usesStoreKit2IfAvailable: true)
            .build()
        Purchases.configure(with: config)
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
    }

    func activeEntitlements() async -> Set<String> {
        // Apple is asked as well as RevenueCat, so a purchase made through the
        // StoreKit fallback still grants access, and so access survives
        // RevenueCat being unreachable.
        let fromApple = await StoreKitStore.ownedEntitlements()
        guard let info = try? await Purchases.shared.customerInfo() else { return fromApple }
        return Set(info.entitlements.active.keys).union(fromApple)
    }

    func refreshEntitlements() async {
        // Make sure the next fetch hits the network. `syncPurchases()` is
        // deliberately avoided — it can trigger an App Store sign-in prompt.
        Purchases.shared.invalidateCustomerInfoCache()
        _ = try? await Purchases.shared.customerInfo()
        await broadcast()
    }

    func restorePurchases() async throws {
        do {
            _ = try await Purchases.shared.restorePurchases()
            await broadcast()
        } catch {
            // Ask Apple directly rather than telling someone who has paid that
            // their purchase cannot be found.
            AppLogger.log("[Purchases] RevenueCat restore failed — asking Apple directly.", level: .warning)
            do {
                try await StoreKitStore.restore()
                await broadcast()
            } catch {
                throw map(error)
            }
        }
    }

    func loadOptions(for entitlement: AppEntitlement) async -> [PurchaseOption] {
        do {
            let offerings = try await Purchases.shared.offerings()
            // Only the offering named for this entitlement. The old fallback to
            // `offerings.current` meant a missing alerts offering quietly sold
            // the radar instead — a wrong price on the wrong paywall, which is
            // worse than showing nothing.
            if let offering = offerings.offering(identifier: entitlement.offeringIdentifier),
               !offering.availablePackages.isEmpty {
                await cache.store(offering.availablePackages)
                return offering.availablePackages.map(option(from:))
            }
            AppLogger.log("[Purchases] No RevenueCat offering '\(entitlement.offeringIdentifier)' — asking Apple directly.", level: .warning)
        } catch {
            AppLogger.log("[Purchases] Offerings fetch failed: \(error.localizedDescription) — asking Apple directly.", level: .error)
        }
        return await StoreKitStore.options(for: entitlement)
    }

    func purchase(packageIdentifier: String) async throws {
        // The paywall already fetched this package; buying should not need to
        // ask RevenueCat a second time.
        guard let package = await cache.package(for: packageIdentifier) else {
            // Nothing cached means the paywall was drawn from StoreKit, so the
            // identifier is an App Store product id and Apple can sell it.
            try await StoreKitStore.purchase(productIdentifier: packageIdentifier)
            await broadcast()
            return
        }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            // RevenueCat reports a cancellation in the result rather than by
            // throwing. Treating it as success made a cancelled purchase look
            // like a silent failure.
            if result.userCancelled { throw PurchaseFriendlyError.cancelled }
            await broadcast()
        } catch let error as PurchaseFriendlyError {
            throw error
        } catch {
            throw map(error)
        }
    }

    func showManageSubscriptions() async {
        try? await Purchases.shared.showManageSubscriptions()
    }

    // MARK: - Helpers

    private func option(from package: Package) -> PurchaseOption {
        let product = package.storeProduct
        let period = product.subscriptionPeriod
        let periodText: String = {
            guard let period else { return String(localized: "paywall.period.onetime") }
            switch period.unit {
            case .day:   return period.value == 7 ? String(localized: "paywall.period.week") : String(localized: "paywall.period.day")
            case .week:  return String(localized: "paywall.period.week")
            case .month: return String(localized: "paywall.period.month")
            case .year:  return String(localized: "paywall.period.year")
            @unknown default: return ""
            }
        }()
        let hasFreeTrial = product.introductoryDiscount.map {
            $0.paymentMode == .freeTrial || $0.price == 0
        } ?? false
        return PurchaseOption(id: package.identifier,
                              displayName: product.localizedTitle,
                              price: product.localizedPriceString,
                              periodText: periodText,
                              hasFreeTrial: hasFreeTrial)
    }

    private func broadcast() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .entitlementsDidChange, object: nil)
        }
    }

    private func map(_ error: Swift.Error) -> Error {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return PurchaseFriendlyError.network }
        if ns.domain.lowercased().contains("revenuecat") {
            let message = ns.localizedDescription.lowercased()
            if message.contains("cancelled") { return PurchaseFriendlyError.cancelled }
            if message.contains("network") { return PurchaseFriendlyError.network }
            if message.contains("ownership") { return PurchaseFriendlyError.ownershipConflict }
        }
        return PurchaseFriendlyError.unknown(ns.localizedDescription)
    }
}

#endif
