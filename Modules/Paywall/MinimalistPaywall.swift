//
//  MinimalistPaywall.swift
//
//  One layout, used by both asks: a header, four benefits, one price, one
//  button. The two paywalls differ in copy and in what they sell — never in
//  how many tiers they show.
//

import SwiftUI

struct MinimalistPaywall: View {
    let content: PaywallContent
    let option: PurchaseOption?
    let isPurchasing: Bool
    /// The store was asked and had nothing to sell. Distinct from "still
    /// asking": a price with a dead button underneath tells the user nothing.
    let loadFailed: Bool
    var onPurchase: () -> Void
    var onRetry: () -> Void
    var onRestore: () -> Void
    var onClose: () -> Void

    var body: some View {
        PaywallScaffold(onClose: onClose) {
            VStack(spacing: DS.Spacing.xl) {
                PaywallPlainHeader(content: content)
                    .padding(.top, DS.Spacing.xl)

                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(content.benefits) { benefit in
                        PaywallBenefitRow(benefit: benefit)
                    }
                }
            }
        } bottom: {
            if loadFailed {
                VStack(spacing: DS.Spacing.sm) {
                    Text("paywall.error.unavailable")
                        .appFont(.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("paywall.retry", action: onRetry)
                        .buttonStyle(DSPrimaryButtonStyle())
                }
            } else {
                PaywallCTAButton(title: content.ctaText(for: option),
                                 subtitle: content.priceDetail(for: option),
                                 isLoading: isPurchasing,
                                 action: onPurchase)
                    .disabled(isPurchasing || option == nil)
                    .opacity(option == nil ? 0.6 : 1)
            }

            PaywallFooter(content: content, onRestore: onRestore)
        }
    }
}
