//
//  PaywallComponents.swift
//
//  DS-themed building blocks shared by both paywalls. Restyle these once and
//  both update. All visuals derive from `DS.*` tokens, so changing brand colors
//  or spacing in DesignSystem.swift restyles them.
//

import SwiftUI

// MARK: - Style knobs

enum PaywallStyle {
    /// Brand gradient used for heroes and icons.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [DS.accent, DS.primary],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// Slightly punchier gradient for the primary CTA.
    static var ctaGradient: LinearGradient {
        LinearGradient(colors: [DS.accent, DS.accent.opacity(0.82)],
                       startPoint: .top, endPoint: .bottom)
    }
    /// Soft tinted background that fades into the system background.
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
        .accessibilityLabel(Text("generic.close"))
    }
}

// MARK: - Header

struct PaywallPlainHeader: View {
    var content: PaywallContent
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let icon = content.heroSystemImage {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(PaywallStyle.brandGradient)
                    .padding(.bottom, DS.Spacing.xs)
            }
            Text(content.title).appFont(.title).multilineTextAlignment(.center)
            if let subtitle = content.subtitle {
                Text(subtitle)
                    .appFont(.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Benefit row

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
                if let subtitle = benefit.subtitle {
                    Text(subtitle).appFont(.footnote).foregroundColor(DS.Colors.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Primary CTA

struct PaywallCTAButton: View {
    var title: String
    var subtitle: String? = nil
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).appFont(.headline)
                    if let subtitle { Text(subtitle).appFont(.caption).opacity(0.95) }
                }
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

// MARK: - Footer

struct PaywallFooter: View {
    @Environment(\.container) private var container

    var content: PaywallContent
    var onRestore: () -> Void
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button(content.restoreText, action: onRestore)
                .appFont(.footnoteSemibold)
                .tint(DS.accent)
            if let footnote = content.footnote {
                Text(footnote)
                    .appFont(.caption2)
                    .foregroundColor(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            // Apple requires functional links to both, next to the price, on
            // any screen selling a subscription. Settings has them too, but a
            // reviewer looks here.
            HStack(spacing: DS.Spacing.md) {
                Link("paywall.legal.terms", destination: container.config.legal.termsURL)
                Link("paywall.legal.privacy", destination: container.config.legal.privacyPolicyURL)
            }
            .appFont(.caption2)
            .tint(DS.Colors.textSecondary)
        }
    }
}

// MARK: - Scaffold (close + scroll + sticky bottom bar)

struct PaywallScaffold<Content: View, Bottom: View>: View {
    var onClose: () -> Void
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
        .background(PaywallStyle.screenBackground.ignoresSafeArea())
    }
}
