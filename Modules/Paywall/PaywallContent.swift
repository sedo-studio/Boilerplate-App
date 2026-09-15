//
//  PaywallContent.swift
//
//  Display model for the paywalls. Prices come from the store at runtime
//  (`PurchaseOption`) — everything here is copy and layout.
//

import Foundation

struct PaywallBenefit: Identifiable, Sendable {
    let id = UUID()
    var icon: String        // SF Symbol
    var title: String
    var subtitle: String?

    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
}

struct PaywallContent: Sendable {
    var title: String
    var subtitle: String?
    var heroSystemImage: String?
    var benefits: [PaywallBenefit]
    /// Call to action. `%@` is replaced with the store price when one loaded.
    var ctaFormat: String
    var restoreText: String
    /// The small print under the button — billing terms, "yours forever", etc.
    var footnote: String?
    /// Shown while the store price is still loading, or if it never arrives.
    var fallbackPriceText: String

    func ctaText(for option: PurchaseOption?) -> String {
        String(format: ctaFormat, option?.price ?? fallbackPriceText)
    }

    func priceDetail(for option: PurchaseOption?) -> String {
        guard let option else { return fallbackPriceText }
        return "\(option.price) \(option.periodText)"
    }
}
