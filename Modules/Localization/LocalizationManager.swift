//
//  LocalizationManager.swift
//
//  PRO feature — in-app language override (switch language without a restart).
//  Self-contained: delete the `Modules/Localization` folder, remove the
//  localization lines in `TheSwiftKitApp.swift` and the Settings entry, drop the
//  extra `*.lproj` folders, and flip `featureFlags.localization` off to remove it.
//

import Foundation
import SwiftUI
import ObjectiveC

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    /// Supported languages. `"system"` follows the device setting.
    /// Add a language: add its `<code>.lproj/Localizable.strings` and a row here.
    static let supported: [(code: String, name: String)] = [
        ("system", "System Default"),
        ("en", "English"),
        ("es", "Español"),
        ("hi", "हिन्दी")
    ]

    @Published private(set) var languageCode: String

    private let key = "appLanguage"

    private init() {
        languageCode = UserDefaults.standard.string(forKey: key) ?? "system"
    }

    /// Locale for date/number formatting and the SwiftUI `\.locale` environment.
    var locale: Locale {
        languageCode == "system" ? Locale.current : Locale(identifier: languageCode)
    }

    func displayName(for code: String) -> String {
        Self.supported.first { $0.code == code }?.name ?? code
    }

    /// Install the runtime-language hook once and apply the saved selection.
    /// Call from app launch when the localization feature is enabled.
    static func installIfNeeded() {
        Bundle.swizzleMainBundleIfNeeded()
        let code = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        Bundle.setLanguage(code)
    }

    func setLanguage(_ code: String) {
        languageCode = code
        if code == "system" {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(code, forKey: key)
        }
        Bundle.setLanguage(code)
        objectWillChange.send()
    }
}

// MARK: - Runtime language override
//
// Overrides Bundle.main's string lookup so `NSLocalizedString`, `String.localized`,
// and SwiftUI `Text("key")` resolve against the chosen `.lproj` at runtime — no
// app restart required. Pair with `.id(localizationManager.languageCode)` at the
// root so the view tree rebuilds when the language changes.

private var associatedLanguageBundleKey: UInt8 = 0

private final class LanguageAwareBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let path = objc_getAssociatedObject(self, &associatedLanguageBundleKey) as? String,
           let bundle = Bundle(path: path) {
            // Use a sentinel so we can detect a missing key in the selected
            // language and gracefully fall back to the base (English) strings —
            // partial translations then never show raw keys.
            let sentinel = "\u{0}__missing__\u{0}"
            let result = bundle.localizedString(forKey: key, value: sentinel, table: tableName)
            if result != sentinel { return result }
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Swap Bundle.main's class for one that can redirect string lookups.
    static func swizzleMainBundleIfNeeded() {
        guard !(Bundle.main is LanguageAwareBundle) else { return }
        object_setClass(Bundle.main, LanguageAwareBundle.self)
    }

    /// Point string lookups at a specific language's `.lproj` (or back to the
    /// system default when `code == "system"`).
    static func setLanguage(_ code: String) {
        let path: String? = (code == "system")
            ? nil
            : Bundle.main.path(forResource: code, ofType: "lproj")
        objc_setAssociatedObject(
            Bundle.main,
            &associatedLanguageBundleKey,
            path,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}
