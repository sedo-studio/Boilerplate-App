//
//  EntitlementPaywallView.swift
//
//  Purchase plumbing shared by the two paywalls: load the product for one
//  entitlement, buy it, restore it, and report the funnel. Each paywall sells
//  exactly one entitlement — there are deliberately no tiers to compare.
//

import SwiftUI

struct EntitlementPaywallView: View {
    let entitlement: AppEntitlement
    let content: PaywallContent
    let viewedEvent: String
    let purchasedEvent: String
    let dismissedEvent: String

    @Environment(\.container) private var container
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlements: Entitlements

    @State private var option: PurchaseOption?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var didPurchase = false
    /// True only once the store has been asked and came back with nothing, so
    /// "still loading" is never mistaken for "nothing to sell".
    @State private var loadFailed = false

    var body: some View {
        MinimalistPaywall(
            content: content,
            option: option,
            isPurchasing: isPurchasing,
            loadFailed: loadFailed,
            onPurchase: purchase,
            onRetry: { Task { await loadOption() } },
            onRestore: restore,
            onClose: close
        )
        .task {
            container.analytics.track(viewedEvent)
            await loadOption()
        }
        .alert(Text("paywall.error.title"), isPresented: .constant(errorMessage != nil)) {
            Button("generic.ok") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadOption() async {
        loadFailed = false
        option = await entitlements.options(for: entitlement).first
        if option == nil {
            loadFailed = true
            AppLogger.log("[Paywall] No product for \(entitlement.rawValue) — neither RevenueCat nor StoreKit returned one.", level: .error)
        }
    }

    private func purchase() {
        guard let option, !isPurchasing else { return }
        isPurchasing = true
        Task {
            do {
                try await entitlements.purchase(option)
                didPurchase = entitlements.owns(entitlement)
                isPurchasing = false
                if didPurchase {
                    container.analytics.track(purchasedEvent)
                    dismiss()
                }
            } catch PurchaseFriendlyError.cancelled {
                // The user changed their mind. Not an error.
                isPurchasing = false
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
                AppLogger.log("[Paywall] Purchase of \(entitlement.rawValue) failed: \(error)", level: .error)
            }
        }
    }

    private func restore() {
        Task {
            do {
                try await entitlements.restore()
                if entitlements.owns(entitlement) {
                    didPurchase = true
                    dismiss()
                } else {
                    errorMessage = String(localized: "paywall.restore.nothing")
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func close() {
        if !didPurchase { container.analytics.track(dismissedEvent) }
        dismiss()
    }
}
