//
//  Template04TrialTimeline.swift
//
//  Hero + a visual trial journey (today → reminder → billing) so users feel
//  safe starting. Apple-endorsed. (Strava, Cal AI, Opal.)
//

import SwiftUI

struct TrialTimelinePaywall: View {
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
                VStack(alignment: .leading, spacing: 0) {
                    row(icon: "lock.open.fill", color: DS.accent,
                        title: "Today", subtitle: "Unlock everything instantly.", isLast: false)
                    row(icon: "bell.fill", color: DS.accent.opacity(0.65),
                        title: "Day 5", subtitle: "We'll remind you before your trial ends.", isLast: false)
                    row(icon: "star.fill", color: Color(.systemGray3),
                        title: "Day 7", subtitle: "Your subscription begins — cancel anytime before.", isLast: true)
                }
                .padding(DS.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        } bottom: {
            Text("No payment due now")
                .appFont(.footnoteSemibold)
                .foregroundColor(DS.success)
            PaywallCTAButton(title: content.trialCtaText,
                             subtitle: "then \(plan.priceText) \(plan.periodText)") { onPurchase(plan) }
            PaywallFooter(content: content, onRestore: onRestore)
        }
    }

    private func row(icon: String, color: Color, title: String, subtitle: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(color))
                if !isLast {
                    Rectangle().fill(Color(.separator)).frame(width: 2, height: 36)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(.headline)
                Text(subtitle).appFont(.footnote).foregroundColor(.secondary)
            }
            .padding(.bottom, isLast ? 0 : DS.Spacing.md)
            Spacer(minLength: 0)
        }
    }
}
