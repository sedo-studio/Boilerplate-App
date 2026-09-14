//
//  PaywallComponents.swift
//
//  Premium, DS-themed building blocks shared by all 10 templates. Restyle these
//  once and every paywall updates. All visuals derive from `DS.*` tokens, so
//  changing your brand colors / spacing in DesignSystem.swift restyles the lot.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Style knobs (the premium "feel" lives here)

enum PaywallStyle {
    /// Brand gradient used for heroes, banners, avatars.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [DS.accent, DS.primary],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// Slightly punchier gradient for the primary CTA.
    static var ctaGradient: LinearGradient {
        LinearGradient(colors: [DS.accent, DS.accent.opacity(0.82)],
                       startPoint: .top, endPoint: .bottom)
    }
    /// Soft tinted screen background that fades into the system background.
    static var screenBackground: LinearGradient {
        LinearGradient(colors: [DS.accent.opacity(0.16), Color(.systemBackground), Color(.systemBackground)],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Close button

struct PaywallCloseButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary.opacity(0.7))
                .padding(DS.Spacing.sm)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

// MARK: - Gradient hero panel (with optional image)

struct PaywallHeroPanel: View {
    var content: PaywallContent
    var height: CGFloat = 260

    private var hasImage: Bool {
        guard let name = content.heroImageName, !name.isEmpty else { return false }
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            if hasImage, let name = content.heroImageName {
                Image(name).resizable().scaledToFill()
                LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                PaywallStyle.brandGradient
                // soft decorative blobs for depth
                Circle().fill(.white.opacity(0.14)).frame(width: 170, height: 170).blur(radius: 10).offset(x: -100, y: -60)
                Circle().fill(.white.opacity(0.10)).frame(width: 130, height: 130).blur(radius: 8).offset(x: 120, y: 40)
            }

            VStack(spacing: DS.Spacing.sm) {
                if let icon = content.heroSystemImage {
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 76, height: 76)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )
                }
                Text(content.title)
                    .appFont(.title)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                if let s = content.subtitle {
                    Text(s)
                        .appFont(.subheadline)
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DS.Spacing.xl)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .shadow(color: DS.accent.opacity(0.25), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Primary CTA (gradient + glow)

struct PaywallCTAButton: View {
    var title: String
    var subtitle: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).appFont(.headline)
                if let subtitle { Text(subtitle).appFont(.caption).opacity(0.95) }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md + 2)
            .background(PaywallStyle.ctaGradient, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .shadow(color: DS.accent.opacity(0.4), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge / pill

struct PaywallBadge: View {
    var text: String
    var filled: Bool = true
    var body: some View {
        Text(text)
            .appFont(.captionBold)
            .foregroundColor(filled ? .white : DS.accent)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 3)
            .background(Capsule().fill(filled ? AnyShapeStyle(PaywallStyle.brandGradient) : AnyShapeStyle(DS.accent.opacity(0.15))))
    }
}

// MARK: - Award badge

struct PaywallAwardBadge: View {
    var text: String
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "trophy.fill").font(.caption)
            Text(text).appFont(.captionBold)
        }
        .foregroundColor(DS.accent)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(Capsule().fill(DS.accent.opacity(0.12)))
        .overlay(Capsule().strokeBorder(DS.accent.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Star rating

struct PaywallStarRating: View {
    var rating: Double
    var count: String? = nil
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: starName(for: i))
                    .font(.footnote)
                    .foregroundColor(.yellow)
            }
            if let count {
                Text(verbatim: String(format: "%.1f (%@)", rating, count))
                    .appFont(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, DS.Spacing.xs)
            }
        }
    }
    private func starName(for index: Int) -> String {
        let value = rating - Double(index)
        if value >= 1 { return "star.fill" }
        if value >= 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

// MARK: - Benefit row (icon chip)

struct PaywallBenefitRow: View {
    var benefit: PaywallBenefit
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: benefit.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DS.accent)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.accent.opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(benefit.title).appFont(.bodyBold)
                if let s = benefit.subtitle {
                    Text(s).appFont(.footnote).foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Ribbon plan card (premium selectable)

struct PaywallRibbonPlanCard: View {
    var plan: PaywallPlan
    var isSelected: Bool
    var action: () -> Void

    private var showsTopBanner: Bool { plan.isHighlighted && plan.badgeText != nil }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if showsTopBanner, let badge = plan.badgeText {
                    Text(badge.uppercased())
                        .appFont(.captionBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(PaywallStyle.brandGradient)
                }
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? DS.accent : Color(.tertiaryLabel))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: DS.Spacing.sm) {
                            Text(plan.name).appFont(.headline)
                            if !showsTopBanner, let badge = plan.badgeText { PaywallBadge(text: badge) }
                        }
                        if let sub = plan.subtitleText {
                            Text(sub).appFont(.footnote).foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: DS.Spacing.sm)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(plan.priceText).appFont(.headline)
                        Text(plan.perPeriodText ?? plan.periodText)
                            .appFont(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(DS.Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(isSelected ? DS.accent : Color(.separator), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .shadow(color: isSelected ? DS.accent.opacity(0.18) : .clear, radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FREE vs PRO comparison table

struct PaywallComparisonTable: View {
    var rows: [PaywallComparisonRow]
    var freeTitle: String = "Free"
    var proTitle: String = "Pro"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Features").appFont(.footnoteSemibold).foregroundColor(.secondary)
                Spacer()
                Text(freeTitle).appFont(.footnoteSemibold).foregroundColor(.secondary).frame(width: 54)
                Text(proTitle).appFont(.footnoteSemibold).foregroundColor(DS.accent).frame(width: 54)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)

            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                HStack {
                    Text(row.feature).appFont(.subheadline)
                    Spacer()
                    mark(row.free).frame(width: 54)
                    mark(row.pro).frame(width: 54)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                if idx < rows.count - 1 {
                    Divider().padding(.leading, DS.Spacing.md)
                }
            }
        }
        .padding(.bottom, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func mark(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark.circle.fill" : "minus")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(on ? DS.accent : Color(.tertiaryLabel))
    }
}

// MARK: - Testimonial card (avatar + stars)

struct PaywallTestimonialCard: View {
    var testimonial: PaywallTestimonial
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Text(initials)
                    .appFont(.footnoteSemibold)
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(PaywallStyle.brandGradient))
                VStack(alignment: .leading, spacing: 1) {
                    Text(testimonial.author).appFont(.footnoteSemibold)
                    PaywallStarRating(rating: Double(testimonial.rating))
                }
                Spacer(minLength: 0)
            }
            Text("“\(testimonial.quote)”").appFont(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
    private var initials: String {
        let chars = testimonial.author.split(separator: " ").prefix(2).compactMap { $0.first }
        return String(chars).uppercased()
    }
}

// MARK: - Promo card (gradient + dashed code chip)

struct PaywallPromoCard: View {
    var content: PaywallContent
    var countdownText: String?

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("Limited time offer").appFont(.subheadline).foregroundColor(.white.opacity(0.9))
            Text(content.offerBadgeText).appFont(.largeTitle).foregroundColor(.white)
            if let code = content.promoCode {
                Text(code)
                    .appFont(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )
            }
            if let countdownText {
                Text(countdownText).appFont(.footnoteSemibold).foregroundColor(.white).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
        .background(PaywallStyle.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .shadow(color: DS.accent.opacity(0.3), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Footer (restore + legal)

struct PaywallFooter: View {
    var content: PaywallContent
    var onRestore: () -> Void
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button(content.restoreText, action: onRestore)
                .appFont(.footnoteSemibold)
                .tint(DS.accent)
            if let foot = content.footnote {
                Text(foot)
                    .appFont(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Simple (non-hero) header for minimalist layouts

struct PaywallPlainHeader: View {
    var content: PaywallContent
    var showIcon: Bool = true
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            if showIcon, let icon = content.heroSystemImage {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(PaywallStyle.brandGradient)
                    .padding(.bottom, DS.Spacing.xs)
            }
            Text(content.title).appFont(.title).multilineTextAlignment(.center)
            if let subtitle = content.subtitle {
                Text(subtitle).appFont(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Scaffold (close + scroll + sticky bottom bar)

struct PaywallScaffold<Content: View, Bottom: View>: View {
    var onClose: () -> Void
    var gradientBackground: Bool = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                PaywallCloseButton(action: onClose)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

            ScrollView {
                content()
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.lg)
            }

            VStack(spacing: DS.Spacing.md) { bottom() }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.md)
                .background(.ultraThinMaterial)
        }
        .background(
            (gradientBackground ? AnyView(PaywallStyle.screenBackground.ignoresSafeArea())
                                : AnyView(Color(.systemBackground).ignoresSafeArea()))
        )
    }
}

// MARK: - CTA copy helpers (free-trial aware)

extension PaywallContent {
    func ctaTitle(for plan: PaywallPlan) -> String {
        plan.hasFreeTrial ? trialCtaText : ctaText
    }
    func ctaSubtitle(for plan: PaywallPlan) -> String? {
        plan.hasFreeTrial ? "then \(plan.priceText) \(plan.periodText)" : "\(plan.priceText) \(plan.periodText)"
    }
}
