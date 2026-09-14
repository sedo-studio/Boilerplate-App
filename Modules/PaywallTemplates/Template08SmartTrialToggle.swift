//
//  Template08SmartTrialToggle.swift
//
//  Hero + benefits + an interactive "free trial" toggle that flips the CTA copy
//  to nudge hesitant users. (OpenChat, Ollie, Tasks.)
//

import SwiftUI

struct SmartTrialTogglePaywall: View {
    let content: PaywallContent
    @Binding var selectedPlanID: String
    var onPurchase: (PaywallPlan) -> Void
    var onRestore: () -> Void
    var onClose: () -> Void

    private var plan: PaywallPlan { content.highlightedPlan }
    @State private var trialEnabled = true

    var body: some View {
        PaywallScaffold(onClose: onClose) {
            VStack(spacing: DS.Spacing.lg) {
                PaywallHeroPanel(content: content, height: 220)

                VStack(spacing: DS.Spacing.md) {
                    ForEach(content.benefits.prefix(3)) { PaywallBenefitRow(benefit: $0) }
                }

                Toggle(isOn: $trialEnabled.animation()) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable free trial").appFont(.headline)
                        Text("Not sure yet? Try everything free first.")
                            .appFont(.footnote).foregroundColor(.secondary)
                    }
                }
                .tint(DS.accent)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

                PaywallRibbonPlanCard(plan: plan, isSelected: true, action: {})
            }
        } bottom: {
            PaywallCTAButton(
                title: trialEnabled ? content.trialCtaText : content.ctaText,
                subtitle: trialEnabled
                    ? "then \(plan.priceText) \(plan.periodText)"
                    : "\(plan.priceText) \(plan.periodText)"
            ) { onPurchase(plan) }
            PaywallFooter(content: content, onRestore: onRestore)
        }
    }
}
