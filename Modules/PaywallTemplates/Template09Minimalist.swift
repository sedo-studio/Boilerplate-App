//
//  Template09Minimalist.swift
//
//  Premium-minimal: gradient icon, refined type, four benefits, one plan.
//  For focused apps that shouldn't overthink the paywall. (Paku.)
//

import SwiftUI

struct MinimalistPaywall: View {
    let content: PaywallContent
    @Binding var selectedPlanID: String
    var onPurchase: (PaywallPlan) -> Void
    var onRestore: () -> Void
    var onClose: () -> Void

    private var plan: PaywallPlan { content.highlightedPlan }

    var body: some View {
        PaywallScaffold(onClose: onClose) {
            VStack(spacing: DS.Spacing.xl) {
                PaywallPlainHeader(content: content)
                    .padding(.top, DS.Spacing.xl)

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(content.benefits.prefix(4)) { b in
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DS.accent)
                            Text(b.title).appFont(.body)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        } bottom: {
            PaywallCTAButton(title: content.ctaTitle(for: plan),
                             subtitle: "\(plan.priceText) \(plan.periodText)") { onPurchase(plan) }
            PaywallFooter(content: content, onRestore: onRestore)
        }
    }
}
