//
//  Template03SocialProof.swift
//
//  Hero + award badge + rating + avatar testimonials, then the plans.
//  (Flo, Speak, YAZIO.)
//

import SwiftUI

struct SocialProofPaywall: View {
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

                if let award = content.awardText {
                    PaywallAwardBadge(text: award)
                }

                VStack(spacing: DS.Spacing.xs) {
                    PaywallStarRating(rating: content.ratingValue, count: content.ratingCount)
                    Text(content.userCountText)
                        .appFont(.footnoteSemibold)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: DS.Spacing.sm) {
                    ForEach(content.testimonials) { PaywallTestimonialCard(testimonial: $0) }
                }

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
