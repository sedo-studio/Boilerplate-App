//
//  LeftBehindPaywallView.swift
//
//  Paywall #2 — the "left behind" alerts subscription. A separate ask, at a
//  separate moment, for ongoing value. It never re-sells the radar.
//

import SwiftUI

struct LeftBehindPaywallView: View {
    var body: some View {
        EntitlementPaywallView(
            entitlement: .leftBehindAlerts,
            content: Self.content,
            viewedEvent: AnalyticsEvent.alertsPaywallViewed,
            purchasedEvent: AnalyticsEvent.alertsPaywallPurchased,
            dismissedEvent: AnalyticsEvent.alertsPaywallDismissed
        )
    }

    private static var content: PaywallContent {
        PaywallContent(
            title: String(localized: "paywall.alerts.title"),
            subtitle: String(localized: "paywall.alerts.subtitle"),
            heroSystemImage: "bell.badge",
            benefits: [
                PaywallBenefit(icon: "bell.badge.fill",
                               title: String(localized: "paywall.alerts.benefit.alert.title"),
                               subtitle: String(localized: "paywall.alerts.benefit.alert.body")),
                PaywallBenefit(icon: "iphone.radiowaves.left.and.right",
                               title: String(localized: "paywall.alerts.benefit.background.title"),
                               subtitle: String(localized: "paywall.alerts.benefit.background.body")),
                PaywallBenefit(icon: "hand.raised.fill",
                               title: String(localized: "paywall.alerts.benefit.private.title"),
                               subtitle: String(localized: "paywall.alerts.benefit.private.body")),
                PaywallBenefit(icon: "arrow.uturn.left",
                               title: String(localized: "paywall.alerts.benefit.cancel.title"),
                               subtitle: String(localized: "paywall.alerts.benefit.cancel.body"))
            ],
            ctaFormat: String(localized: "paywall.alerts.cta"),
            restoreText: String(localized: "paywall.restore"),
            footnote: String(localized: "paywall.alerts.footnote"),
            fallbackPriceText: "$4.99"
        )
    }
}

struct LeftBehindPaywallView_Previews: PreviewProvider {
    static var previews: some View {
        LeftBehindPaywallView()
            .environmentObject(Entitlements(purchases: LocalPurchasesService(), flags: .default))
    }
}
