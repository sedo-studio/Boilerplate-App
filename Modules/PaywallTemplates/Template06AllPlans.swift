//
//  Template06AllPlans.swift
//
//  FREE vs PRO comparison table — the highest-value-perception layout — with
//  plan cards below. (Study Routine, Premium-tier paywalls.)
//

import SwiftUI

struct AllPlansPaywall: View {
    let content: PaywallContent
    @Binding var selectedPlanID: String
    var onPurchase: (PaywallPlan) -> Void
    var onRestore: () -> Void
    var onClose: () -> Void

    private var plan: PaywallPlan { content.plan(selectedPlanID) ?? content.highlightedPlan }

    var body: some View {
        PaywallScaffold(onClose: onClose) {
            VStack(spacing: DS.Spacing.lg) {
                PaywallHeroPanel(content: content, height: 220)
                PaywallComparisonTable(rows: content.comparison)
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(content.plans.prefix(2)) { p in
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
