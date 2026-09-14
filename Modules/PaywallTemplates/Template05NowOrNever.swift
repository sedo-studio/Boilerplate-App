//
//  Template05NowOrNever.swift
//
//  Gradient promo card with a dashed code chip + live countdown + struck-through
//  original price to drive urgency. (Captions, Finch, YAZIO.)
//

import SwiftUI

struct NowOrNeverPaywall: View {
    let content: PaywallContent
    @Binding var selectedPlanID: String
    var onPurchase: (PaywallPlan) -> Void
    var onRestore: () -> Void
    var onClose: () -> Void

    private var plan: PaywallPlan { content.highlightedPlan }

    @State private var remaining: Int = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        PaywallScaffold(onClose: onClose) {
            VStack(spacing: DS.Spacing.lg) {
                PaywallPromoCard(content: content, countdownText: timeString)
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Everything in Pro").appFont(.headline)
                    ForEach(content.benefits.prefix(4)) { PaywallBenefitRow(benefit: $0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } bottom: {
            HStack(spacing: DS.Spacing.sm) {
                if let orig = content.originalPriceText {
                    Text(orig).appFont(.subheadline).foregroundColor(.secondary).strikethrough()
                }
                Text("\(plan.priceText) \(plan.periodText)").appFont(.headline)
                Spacer()
                PaywallBadge(text: content.offerBadgeText)
            }
            PaywallCTAButton(title: "Claim \(content.offerBadgeText)",
                             subtitle: content.promoCode.map { "Code \($0) applied" }) { onPurchase(plan) }
            PaywallFooter(content: content, onRestore: onRestore)
        }
        .onAppear { if remaining == 0 { remaining = content.countdownSeconds } }
        .onReceive(ticker) { _ in if remaining > 0 { remaining -= 1 } }
    }

    private var timeString: String? {
        guard remaining > 0 else { return "Offer expired" }
        let m = remaining / 60, s = remaining % 60
        return String(format: "Ends in %02d:%02d", m, s)
    }
}
