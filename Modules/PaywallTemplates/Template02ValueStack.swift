//
//  Template02ValueStack.swift
//
//  Hero + a card of icon-chip benefits framing the purchase as "unlock many
//  things". (MyFitnessPal, ChatOn AI.)
//

import SwiftUI

struct ValueStackPaywall: View {
    let content: PaywallContent
    @Binding var selectedPlanID: String
    var onPurchase: (PaywallPlan) -> Void
    var onRestore: () -> Void
    var onClose: () -> Void

    private var plan: PaywallPlan { content.highlightedPlan }

    var body: some View {
        PaywallScaffold(onClose: onClose) {
            VStack(spacing: DS.Spacing.lg) {
                PaywallHeroPanel(content: content, height: 220)
                VStack(spacing: DS.Spacing.md) {
                    ForEach(content.benefits) { PaywallBenefitRow(benefit: $0) }
                }
                .padding(DS.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        } bottom: {
            HStack(spacing: DS.Spacing.sm) {
                Text(plan.priceText).appFont(.headline)
                Text(plan.perPeriodText ?? plan.periodText)
                    .appFont(.footnote).foregroundColor(.secondary)
                Spacer()
                if let badge = plan.badgeText { PaywallBadge(text: badge) }
            }
            PaywallCTAButton(title: content.ctaTitle(for: plan),
                             subtitle: content.ctaSubtitle(for: plan)) { onPurchase(plan) }
            PaywallFooter(content: content, onRestore: onRestore)
        }
    }
}
