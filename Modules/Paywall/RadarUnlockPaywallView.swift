//
//  RadarUnlockPaywallView.swift
//
//  Paywall #1 — the one-time radar unlock, shown right after the free "found
//  nearby" moment. One product, one price, no subscription.
//

import SwiftUI

struct RadarUnlockPaywallView: View {
    var body: some View {
        EntitlementPaywallView(
            entitlement: .radarUnlock,
            content: Self.content,
            viewedEvent: AnalyticsEvent.radarPaywallViewed,
            purchasedEvent: AnalyticsEvent.radarPaywallPurchased,
            dismissedEvent: AnalyticsEvent.radarPaywallDismissed
        )
    }

    private static var content: PaywallContent {
        PaywallContent(
            title: String(localized: "paywall.radar.title"),
            subtitle: String(localized: "paywall.radar.subtitle"),
            heroSystemImage: "dot.radiowaves.forward",
            benefits: [
                PaywallBenefit(icon: "dot.radiowaves.left.and.right",
                               title: String(localized: "paywall.radar.benefit.live.title"),
                               subtitle: String(localized: "paywall.radar.benefit.live.body")),
                PaywallBenefit(icon: "thermometer.medium",
                               title: String(localized: "paywall.radar.benefit.warmer.title"),
                               subtitle: String(localized: "paywall.radar.benefit.warmer.body")),
                PaywallBenefit(icon: "wifi.slash",
                               title: String(localized: "paywall.radar.benefit.offline.title"),
                               subtitle: String(localized: "paywall.radar.benefit.offline.body")),
                PaywallBenefit(icon: "infinity",
                               title: String(localized: "paywall.radar.benefit.onetime.title"),
                               subtitle: String(localized: "paywall.radar.benefit.onetime.body"))
            ],
            ctaFormat: String(localized: "paywall.radar.cta"),
            restoreText: String(localized: "paywall.restore"),
            footnote: String(localized: "paywall.radar.footnote"),
            fallbackPriceText: "$9.99"
        )
    }
}

struct RadarUnlockPaywallView_Previews: PreviewProvider {
    static var previews: some View {
        RadarUnlockPaywallView()
            .environmentObject(Entitlements(purchases: LocalPurchasesService(), flags: .default))
    }
}
