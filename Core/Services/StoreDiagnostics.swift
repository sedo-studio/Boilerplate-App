//
//  StoreDiagnostics.swift
//
//  A debug-only end-to-end check of the purchase stack.
//
//  Connecting RevenueCat spans four places that can each be wrong on their own:
//  the SDK package, the API key, the products in App Store Connect, and the
//  offerings that group them. A paywall with no buttons looks identical in all
//  four cases, so this asks the live stack what it can actually see and says
//  which link is broken.
//

#if DEBUG
import Foundation

struct StoreDiagnostics {
    var lines: [String] = []

    /// Runs the whole chain. Safe to call repeatedly; it only reads.
    static func gather(container: DIContainer) async -> StoreDiagnostics {
        var report = StoreDiagnostics()

        #if canImport(RevenueCat)
        report.lines.append("SDK linked: yes")
        #else
        report.lines.append("SDK linked: NO — add the RevenueCat package")
        #endif

        let isStub = container.purchasesService is LocalPurchasesService
        report.lines.append("API key: \(Secrets.revenueCatAPIKey.isEmpty ? "MISSING" : "set (\(Secrets.revenueCatAPIKey.prefix(6))…)")")
        report.lines.append("Serving: \(isStub ? "local stub — debug-only fake purchases" : "RevenueCat")")

        for entitlement in AppEntitlement.allCases {
            let options = await container.purchasesService.loadOptions(for: entitlement)
            if options.isEmpty {
                report.lines.append("offering '\(entitlement.offeringIdentifier)': NO PACKAGES")
            } else {
                let packages = options.map { "\($0.id) \($0.price)" }.joined(separator: ", ")
                report.lines.append("offering '\(entitlement.offeringIdentifier)': \(packages)")
            }
        }

        let active = await container.purchasesService.activeEntitlements()
        report.lines.append("owned: \(active.isEmpty ? "nothing" : active.sorted().joined(separator: ", "))")

        return report
    }

    var text: String { lines.joined(separator: "\n") }
}
#endif
