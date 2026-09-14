//
//  PaywallTemplateModels.swift
//
//  PRO feature — 10 ready-to-use paywall templates.
//
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │ CUSTOMIZE EVERYTHING FROM ONE PLACE                                   │
//  │ • Text / plans / benefits / social proof → edit `PaywallContent`      │
//  │   (or `PaywallContent.sample`), or build your own and pass it in.     │
//  │ • Colors / spacing / corners / fonts → edit Core/Theme/DesignSystem.  │
//  │ • Shared look of buttons/rows → edit PaywallComponents.swift.          │
//  │ • Keep only the templates you want — each is its own file.            │
//  └─────────────────────────────────────────────────────────────────────┘
//
//  Self-contained: delete the `Modules/PaywallTemplates` folder + flip
//  `featureFlags.paywallTemplates` off to remove this feature entirely.
//

import Foundation

// MARK: - Plan

/// A single purchasable plan shown on a paywall. Keep this provider-agnostic so
/// the templates render in previews/demo without RevenueCat configured. Map a
/// RevenueCat `Package` → `PaywallPlan` when wiring real products (see
/// `PaywallContent` doc comment for the mapping pattern).
struct PaywallPlan: Identifiable, Equatable, Sendable {
    var id: String              // product identifier (e.g. RevenueCat product id)
    var name: String            // "Yearly"
    var priceText: String       // "$39.99"
    var periodText: String      // "/ year", "once"
    var subtitleText: String?   // "7-day free trial, then billed yearly"
    var badgeText: String?      // "Save 80%", "Most Popular"
    var perPeriodText: String?  // "$3.33 / mo"
    var isHighlighted: Bool      // default-selected / emphasized
    var hasFreeTrial: Bool

    init(id: String, name: String, priceText: String, periodText: String,
         subtitleText: String? = nil, badgeText: String? = nil, perPeriodText: String? = nil,
         isHighlighted: Bool = false, hasFreeTrial: Bool = false) {
        self.id = id; self.name = name; self.priceText = priceText; self.periodText = periodText
        self.subtitleText = subtitleText; self.badgeText = badgeText; self.perPeriodText = perPeriodText
        self.isHighlighted = isHighlighted; self.hasFreeTrial = hasFreeTrial
    }
}

// MARK: - Benefit / Testimonial

struct PaywallBenefit: Identifiable, Sendable {
    let id = UUID()
    var icon: String        // SF Symbol name
    var title: String
    var subtitle: String?

    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon; self.title = title; self.subtitle = subtitle
    }
}

struct PaywallTestimonial: Identifiable, Sendable {
    let id = UUID()
    var quote: String
    var author: String
    var rating: Int         // 0...5

    init(quote: String, author: String, rating: Int = 5) {
        self.quote = quote; self.author = author; self.rating = rating
    }
}

/// A row in the FREE vs PRO comparison-table template.
struct PaywallComparisonRow: Identifiable, Sendable {
    let id = UUID()
    var feature: String
    var free: Bool
    var pro: Bool
    init(_ feature: String, free: Bool = false, pro: Bool = true) {
        self.feature = feature; self.free = free; self.pro = pro
    }
}

// MARK: - Content (the one config that drives all 10 templates)

struct PaywallContent: Sendable {
    // Header
    var title: String
    var subtitle: String?
    var heroSystemImage: String?

    // Body
    var benefits: [PaywallBenefit]
    var plans: [PaywallPlan]

    // Social proof
    var ratingValue: Double
    var ratingCount: String
    var userCountText: String
    var testimonials: [PaywallTestimonial]

    // CTA / legal
    var ctaText: String
    var trialCtaText: String
    var restoreText: String
    var footnote: String?

    // Limited-time offer (used by the "Now or Never" template)
    var offerBadgeText: String
    var countdownSeconds: Int

    // Rich content (premium templates)
    /// Optional image asset name for the hero. When nil, a themed gradient hero
    /// is shown — drop your own illustration/screenshot in Assets and set this.
    var heroImageName: String? = nil
    /// e.g. "App of the Year 2025" — shown as an award badge.
    var awardText: String? = nil
    /// Rows for the FREE vs PRO comparison-table template.
    var comparison: [PaywallComparisonRow] = []
    /// Promo code shown on the limited-time template (e.g. "SUMMER25").
    var promoCode: String? = nil
    /// Original (pre-discount) price, shown struck through on the offer template.
    var originalPriceText: String? = nil

    /// The default plan to select when a template first appears.
    var defaultPlanID: String {
        plans.first(where: { $0.isHighlighted })?.id ?? plans.first?.id ?? ""
    }

    func plan(_ id: String) -> PaywallPlan? { plans.first(where: { $0.id == id }) }
    var highlightedPlan: PaywallPlan { plans.first(where: { $0.isHighlighted }) ?? plans.first ?? Self.sample.plans[0] }
}

extension PaywallContent {
    /// Sample content used by the demo gallery and SwiftUI previews.
    /// Replace these values (or build your own `PaywallContent`) to brand the
    /// paywalls. To wire real products, map your RevenueCat offering to `plans`:
    ///
    /// ```swift
    /// let plans = offering.availablePackages.map { pkg in
    ///     PaywallPlan(id: pkg.storeProduct.productIdentifier,
    ///                 name: pkg.packageType.description,
    ///                 priceText: pkg.storeProduct.localizedPriceString,
    ///                 periodText: ...)
    /// }
    /// ```
    static var sample: PaywallContent {
        PaywallContent(
            title: "Unlock Pro",
            subtitle: "Everything you need, with no limits.",
            heroSystemImage: "crown.fill",
            benefits: [
                PaywallBenefit(icon: "infinity", title: "Unlimited access", subtitle: "No caps, no limits"),
                PaywallBenefit(icon: "bolt.fill", title: "Faster performance", subtitle: "Priority processing"),
                PaywallBenefit(icon: "lock.open.fill", title: "All premium features", subtitle: "Unlock the full app"),
                PaywallBenefit(icon: "icloud.fill", title: "Cloud sync", subtitle: "Across all your devices"),
                PaywallBenefit(icon: "sparkles", title: "Early access", subtitle: "New features first")
            ],
            plans: [
                PaywallPlan(id: "pro_yearly", name: "Yearly", priceText: "$39.99", periodText: "/ year",
                            subtitleText: "7-day free trial, then billed yearly", badgeText: "Save 80%",
                            perPeriodText: "$3.33 / mo", isHighlighted: true, hasFreeTrial: true),
                PaywallPlan(id: "pro_monthly", name: "Monthly", priceText: "$9.99", periodText: "/ month"),
                PaywallPlan(id: "pro_lifetime", name: "Lifetime", priceText: "$99.99", periodText: "once",
                            subtitleText: "One-time purchase", badgeText: "Best Deal")
            ],
            ratingValue: 4.8,
            ratingCount: "12k",
            userCountText: "Join 50,000+ members",
            testimonials: [
                PaywallTestimonial(quote: "This completely changed my daily routine.", author: "Alex P."),
                PaywallTestimonial(quote: "Worth every penny — the pro features are incredible.", author: "Sam R."),
                PaywallTestimonial(quote: "The best in its category, hands down.", author: "Jordan T.", rating: 5)
            ],
            ctaText: "Continue",
            trialCtaText: "Start Free Trial",
            restoreText: "Restore Purchases",
            footnote: "Cancel anytime. Recurring billing. Terms & Privacy apply.",
            offerBadgeText: "75% OFF",
            countdownSeconds: 10 * 60,
            awardText: "App of the Year 2025",
            comparison: [
                PaywallComparisonRow("Core features", free: true, pro: true),
                PaywallComparisonRow("Unlimited access", free: false, pro: true),
                PaywallComparisonRow("Ad-free experience", free: false, pro: true),
                PaywallComparisonRow("Cloud sync", free: false, pro: true),
                PaywallComparisonRow("Priority support", free: false, pro: true)
            ],
            promoCode: "SUMMER25",
            originalPriceText: "$59.99"
        )
    }
}

// MARK: - Template registry

/// The 10 templates. Add/remove cases here and in `PaywallTemplateHost`'s switch.
enum PaywallTemplate: String, CaseIterable, Identifiable, Sendable {
    case anchorDecoy
    case valueStack
    case socialProof
    case trialTimeline
    case nowOrNever
    case allPlans
    case featureCarousel
    case smartTrialToggle
    case minimalist
    case uiShowcase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anchorDecoy:      return "Anchor & Decoy"
        case .valueStack:       return "Value Stack"
        case .socialProof:      return "Social Proof"
        case .trialTimeline:    return "Trial Timeline"
        case .nowOrNever:       return "Now or Never"
        case .allPlans:         return "Compare Plans"
        case .featureCarousel:  return "Feature Carousel"
        case .smartTrialToggle: return "Smart Trial Toggle"
        case .minimalist:       return "Minimalist"
        case .uiShowcase:       return "UI Showcase"
        }
    }

    var blurb: String {
        switch self {
        case .anchorDecoy:      return "3 plans, badges & savings — anchoring bias"
        case .valueStack:       return "Icon benefit list + one CTA"
        case .socialProof:      return "Testimonials, rating & user count"
        case .trialTimeline:    return "Day 1 → 28 → 30 trial timeline"
        case .nowOrNever:       return "Countdown timer + discount urgency"
        case .allPlans:         return "FREE vs PRO comparison table"
        case .featureCarousel:  return "Paged benefit highlights → CTA"
        case .smartTrialToggle: return "Free-trial toggle flips plan & CTA"
        case .minimalist:       return "Four benefits, one plan, no clutter"
        case .uiShowcase:       return "Embeds app UI chunks into the paywall"
        }
    }

    var systemImage: String {
        switch self {
        case .anchorDecoy:      return "square.stack.3d.up.fill"
        case .valueStack:       return "checklist"
        case .socialProof:      return "star.bubble.fill"
        case .trialTimeline:    return "calendar.badge.clock"
        case .nowOrNever:       return "timer"
        case .allPlans:         return "rectangle.3.group.fill"
        case .featureCarousel:  return "rectangle.portrait.on.rectangle.portrait.fill"
        case .smartTrialToggle: return "switch.2"
        case .minimalist:       return "circle"
        case .uiShowcase:       return "apps.iphone"
        }
    }
}
