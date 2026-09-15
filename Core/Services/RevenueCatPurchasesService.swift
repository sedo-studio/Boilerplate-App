//
//  RevenueCatPurchasesService.swift
//

import Foundation

#if canImport(RevenueCat)
import RevenueCat

struct RevenueCatPurchasesService: PurchasesService {
    private let apiKey: String

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
        guard let info = try? await Purchases.shared.customerInfo() else { return [] }
        return Set(info.entitlements.active.keys)
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
            throw map(error)
        }
    }

    func loadOptions(for entitlement: AppEntitlement) async -> [PurchaseOption] {
        do {
            let offerings = try await Purchases.shared.offerings()
            // Fall back to the current offering so a misnamed offering still
            // shows something rather than an empty paywall.
            let offering = offerings.offering(identifier: entitlement.offeringIdentifier) ?? offerings.current
            guard let offering else { return [] }
            return offering.availablePackages.map(option(from:))
        } catch {
            AppLogger.log("Offerings fetch failed: \(error.localizedDescription)", level: .error)
            return []
        }
    }

    func purchase(packageIdentifier: String) async throws {
        let offerings = try await Purchases.shared.offerings()
        let package: Package? = offerings.all.values
            .compactMap { $0.availablePackages.first(where: { $0.identifier == packageIdentifier }) }
            .first
        guard let package else { throw PurchaseFriendlyError.unknown("Product not found.") }
        do {
            _ = try await Purchases.shared.purchase(package: package)
            await broadcast()
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
