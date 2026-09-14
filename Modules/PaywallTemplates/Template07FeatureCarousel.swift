//
//  Template07FeatureCarousel.swift
//
//  Full-screen paged benefit highlights with gradient icon medallions, ending
//  on a strong CTA. (ROI, Pestle.)
//

import SwiftUI

struct FeatureCarouselPaywall: View {
    let content: PaywallContent
    @Binding var selectedPlanID: String
    var onPurchase: (PaywallPlan) -> Void
    var onRestore: () -> Void
    var onClose: () -> Void

    private var plan: PaywallPlan { content.highlightedPlan }
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                PaywallCloseButton(action: onClose)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

            TabView(selection: $page) {
                ForEach(Array(content.benefits.enumerated()), id: \.offset) { idx, b in
                    VStack(spacing: DS.Spacing.lg) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(PaywallStyle.brandGradient)
                                .frame(width: 128, height: 128)
                                .shadow(color: DS.accent.opacity(0.4), radius: 24, x: 0, y: 12)
                            Image(systemName: b.icon)
                                .font(.system(size: 52, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(b.title)
                            .appFont(.title2)
                            .multilineTextAlignment(.center)
                        if let s = b.subtitle {
                            Text(s)
                                .appFont(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(DS.Spacing.xl)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: DS.Spacing.md) {
                PaywallCTAButton(title: content.ctaTitle(for: plan),
                                 subtitle: content.ctaSubtitle(for: plan)) { onPurchase(plan) }
                PaywallFooter(content: content, onRestore: onRestore)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.md)
        }
        .background(PaywallStyle.screenBackground.ignoresSafeArea())
    }
}
