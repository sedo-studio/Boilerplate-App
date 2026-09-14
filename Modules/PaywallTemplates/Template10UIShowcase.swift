//
//  Template10UIShowcase.swift
//
//  Hero + a 2-column grid of feature cards so users can picture what they
//  unlock. (Goalkit, Sunlitt, CatGPT Dev Tools.)
//
//  Customize: swap the icon medallions for real screenshots (Image("...")).
//

import SwiftUI

struct UIShowcasePaywall: View {
    let content: PaywallContent
    @Binding var selectedPlanID: String
    var onPurchase: (PaywallPlan) -> Void
    var onRestore: () -> Void
    var onClose: () -> Void

    private var plan: PaywallPlan { content.highlightedPlan }
    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    var body: some View {
        PaywallScaffold(onClose: onClose) {
            VStack(spacing: DS.Spacing.lg) {
                PaywallHeroPanel(content: content, height: 220)
                LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                    ForEach(content.benefits.prefix(4)) { featureCard($0) }
                }
            }
        } bottom: {
            PaywallCTAButton(title: content.ctaTitle(for: plan),
                             subtitle: content.ctaSubtitle(for: plan)) { onPurchase(plan) }
            PaywallFooter(content: content, onRestore: onRestore)
        }
    }

    private func featureCard(_ b: PaywallBenefit) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Image(systemName: b.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(DS.accent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.accent.opacity(0.12))
                )
            Text(b.title).appFont(.headline)
            if let s = b.subtitle {
                Text(s).appFont(.footnote).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
