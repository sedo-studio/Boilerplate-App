//
//  Template01AnchorDecoy.swift
//
//  Gradient hero + three ribboned plan cards with a "MOST POPULAR" banner and
//  "Save 80%" emphasis. (Calm, MacroFactor, SCRL.)
//

import SwiftUI

struct AnchorDecoyPaywall: View {
    let content: PaywallContent
    @Binding var selectedPlanID: String
    var onPurchase: (PaywallPlan) -> Void
    var onRestore: () -> Void
    var onClose: () -> Void

    private var plan: PaywallPlan { content.plan(selectedPlanID) ?? content.highlightedPlan }

    var body: some View {
        PaywallScaffold(onClose: onClose) {
            VStack(spacing: DS.Spacing.lg) {
                PaywallHeroPanel(content: content)
                VStack(spacing: DS.Spacing.md) {
                    ForEach(content.benefits.prefix(3)) { PaywallBenefitRow(benefit: $0) }
                }
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(content.plans) { p in
                        PaywallRibbonPlanCard(plan: p, isSelected: p.id == selectedPlanID) {
                            selectedPlanID = p.id
                        }
                    }
                }
            }
        } bottom: {
            PaywallCTAButton(title: content.ctaTitle(for: plan),
                             subtitle: content.ctaSubtitle(for: plan)) { onPurchase(plan) }
            PaywallFooter(content: content, onRestore: onRestore)
        }
    }
}
