//
//  DSColors.swift
//
//  Semantic color roles derived from DesignSystem.swift tokens.
//  These adapt automatically to light/dark mode.
//
//  You rarely need to edit this file — change the hex values in
//  DesignSystem.swift instead.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Semantic Color Roles

extension DS {

    /// Adaptive semantic colors that resolve from the neutral palette
    /// and automatically switch between light and dark mode.
    public enum Colors {

        // MARK: Backgrounds

        /// Main screen background.
        public static var background: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral900Hex) ?? .systemBackground)
                    : (UIColor(hex: DS.neutral50Hex) ?? .systemBackground)
            })
        }

        /// Card / elevated surface background.
        public static var surface: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral800Hex) ?? .secondarySystemBackground)
                    : .white
            })
        }

        /// Secondary surface (grouped content, inner cards).
        public static var surfaceSecondary: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral700Hex) ?? .tertiarySystemBackground)
                    : (UIColor(hex: DS.neutral100Hex) ?? .tertiarySystemBackground)
            })
        }

        // MARK: Text

        /// Primary text / headings.
        public static var textPrimary: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral50Hex) ?? .label)
                    : (UIColor(hex: DS.neutral900Hex) ?? .label)
            })
        }

        /// Secondary / supporting text.
        public static var textSecondary: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral400Hex) ?? .secondaryLabel)
                    : (UIColor(hex: DS.neutral500Hex) ?? .secondaryLabel)
            })
        }

        /// Tertiary / placeholder text.
        public static var textTertiary: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral600Hex) ?? .tertiaryLabel)
                    : (UIColor(hex: DS.neutral400Hex) ?? .tertiaryLabel)
            })
        }

        // MARK: Borders & Dividers

        public static var border: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral700Hex) ?? .separator)
                    : (UIColor(hex: DS.neutral200Hex) ?? .separator)
            })
        }

        public static var divider: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral800Hex) ?? .opaqueSeparator)
                    : (UIColor(hex: DS.neutral200Hex) ?? .opaqueSeparator)
            })
        }

        // MARK: Button Colors

        /// Primary button background (uses accent).
        public static var buttonPrimaryBg: Color { DS.accent }

        /// Primary button foreground. Auto-selects white or black for contrast.
        public static var buttonPrimaryFg: Color {
            contrastForeground(for: DS.accentHex)
        }

        /// Secondary / outline button.
        public static var buttonSecondaryBg: Color { .clear }
        public static var buttonSecondaryFg: Color { DS.accent }

        // MARK: Helpers

        /// Colour for a signal strength on 0 (weakest) … 1 (strongest),
        /// walking the multi-stop temperature ramp in `DS.temperatureStops`.
        ///
        /// Each segment is blended separately. Blending the endpoints directly
        /// would run blue → red through magenta and put purple — a colour that
        /// reads as neither hot nor cold — right in the middle of the range.
        public static func temperature(_ amount: Double) -> Color {
            let t = min(max(amount, 0), 1)
            let stops = DS.temperatureStops
            guard let upperIndex = stops.firstIndex(where: { $0.position >= t }) else {
                return stops[stops.count - 1].color
            }
            guard upperIndex > 0 else { return stops[0].color }

            let lower = stops[upperIndex - 1]
            let upper = stops[upperIndex]
            let span = upper.position - lower.position
            let localT = span > 0 ? (t - lower.position) / span : 0
            return blend(lower.color, upper.color, amount: localT)
        }

        /// Mixes two colors. `amount` 0 returns `from`, 1 returns `to`.
        public static func blend(_ from: Color, _ to: Color, amount: Double) -> Color {
            #if canImport(UIKit)
            let t = min(max(amount, 0), 1)
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            UIColor(from).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            UIColor(to).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            return Color(.sRGB,
                         red: Double(r1 + (r2 - r1) * t),
                         green: Double(g1 + (g2 - g1) * t),
                         blue: Double(b1 + (b2 - b1) * t),
                         opacity: Double(a1 + (a2 - a1) * t))
            #else
            return amount < 0.5 ? from : to
            #endif
        }

        /// Returns white or black depending on which provides better contrast
        /// against the given hex background.
        private static func contrastForeground(for hex: String) -> Color {
            guard let c = UIColor(hex: hex) else { return .white }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            return luminance > 0.5 ? .black : .white
        }
    }
}

// MARK: - Color(hex:) Extension

extension Color {
    public init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else { return nil }
        let r, g, b, a: Double
        switch hexString.count {
        case 6:
            r = Double((hexNumber & 0xFF0000) >> 16) / 255
            g = Double((hexNumber & 0x00FF00) >> 8) / 255
            b = Double(hexNumber & 0x0000FF) / 255
            a = 1.0
        case 8:
            r = Double((hexNumber & 0xFF000000) >> 24) / 255
            g = Double((hexNumber & 0x00FF0000) >> 16) / 255
            b = Double((hexNumber & 0x0000FF00) >> 8) / 255
            a = Double(hexNumber & 0x000000FF) / 255
        default:
            return nil
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - UIColor(hex:) Extension

#if canImport(UIKit)
extension UIColor {
    public convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else { return nil }
        let r, g, b, a: CGFloat
        switch hexString.count {
        case 6:
            r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000FF) / 255
            a = 1.0
        case 8:
            r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000FF) / 255
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
#endif
