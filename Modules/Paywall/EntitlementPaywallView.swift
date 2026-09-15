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

    var body: some View {
        MinimalistPaywall(
            content: content,
            option: option,
            isPurchasing: isPurchasing,
            onPurchase: purchase,
            onRestore: restore,
            onClose: close
        )
        .task {
            container.analytics.track(viewedEvent)
            option = await entitlements.options(for: entitlement).first
        }
        .alert(Text("paywall.error.title"), isPresented: .constant(errorMessage != nil)) {
            Button("generic.ok") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
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
                isPurchasing = false
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
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
