//
//  FeatureFlags.swift
//

import Foundation

public struct FeatureFlags: Codable, Sendable {
    public var onboarding: Bool
    public var auth: Bool
    public var paywall: Bool
    public var notifications: Bool
    /// Enable the AI feature module (chat, image gen, vision) on the home screen.
    public var aiFeatures: Bool
    /// Enable the "Sign in with Apple" button on the sign-in screen.
    /// Requires the "Sign in with Apple" capability in Xcode and a configured
    /// Apple provider in your Supabase project. See `AppleSignInService.swift` for setup steps.
    public var appleSignIn: Bool
    /// Enable the centralized caching layer.
    /// When `true`, repositories are wrapped in cached decorators (e.g.,
    /// `CachedProfileRepository`, `CachedSubscriptionRepository`) that serve
    /// fresh data from an in-memory + UserDefaults cache before hitting the network.
    /// Toggle this off to bypass caching entirely -- useful for debugging.
    public var enableCaching: Bool

    // ─────────────────────────────────────────────────────────────────────
    // PRO features — each lives in its own self-contained folder so it can be
    // removed by (1) flipping its flag off here and (2) deleting the folder.
    // ─────────────────────────────────────────────────────────────────────

    /// Enable the Swift Charts demo module (`Modules/Charts`).
    public var charts: Bool
    /// Enable the App Store review prompt feature (`Modules/Review` +
    /// `Core/Services/RatingService.swift`): a native StoreKit request plus a
    /// custom pre-prompt, triggered after a configurable number of key actions.
    public var reviewPrompt: Bool
    /// Enable the in-app feedback module (`Modules/Feedback`): a form that
    /// collects a category + message and submits via `FeedbackService`.
    public var inAppFeedback: Bool
    /// Enable biometric (Face ID / Touch ID) app lock (`Modules/AppLock`).
    /// NOTE: this flag only makes the feature *available*; the user still opts
    /// in via the toggle in Settings (persisted as `appLockEnabled`).
    public var biometricLock: Bool
    /// Enable the in-app language override (`Modules/Localization`): a picker in
    /// Settings that switches `Localizable.strings` at runtime without a restart.
    public var localization: Bool
    /// Enable the 10 paywall templates + preview gallery (`Modules/PaywallTemplates`).
    public var paywallTemplates: Bool
    /// Enable home/lock-screen Widgets + Live Activities (`Widgets/` + widget target).
    public var widgets: Bool
    /// Enable the questionnaire/quiz onboarding flow (`Modules/QuestionnaireOnboarding`).
    public var questionnaireOnboarding: Bool
    /// Enable the gamification engine — XP, levels, badges, streaks (`Modules/Gamification`).
    public var gamification: Bool
    /// Enable AI PRO — streaming chat + persisted history (`Modules/AIPro`).
    public var aiPro: Bool
    /// Enable camera + document scanner + OCR (`Modules/Capture`).
    public var camera: Bool
    /// Enable local reminder / notification scheduling (`Modules/Reminders`).
    public var reminders: Bool
    /// Enable the SwiftData offline-first store demo (`Modules/SwiftDataStore`).
    public var swiftDataStore: Bool

    public init(
        onboarding: Bool = false,
        auth: Bool = false,
        paywall: Bool = false,
        notifications: Bool = false,
        aiFeatures: Bool = false,
        appleSignIn: Bool = false,
        enableCaching: Bool = true,
        charts: Bool = false,
        reviewPrompt: Bool = false,
        inAppFeedback: Bool = false,
        biometricLock: Bool = false,
        localization: Bool = false,
        paywallTemplates: Bool = false,
        widgets: Bool = false,
        questionnaireOnboarding: Bool = false,
        gamification: Bool = false,
        aiPro: Bool = false,
        camera: Bool = false,
        reminders: Bool = false,
        swiftDataStore: Bool = false
    ) {
        self.onboarding = onboarding
        self.auth = auth
        self.paywall = paywall
        self.notifications = notifications
        self.aiFeatures = aiFeatures
        self.appleSignIn = appleSignIn
        self.enableCaching = enableCaching
        self.charts = charts
        self.reviewPrompt = reviewPrompt
        self.inAppFeedback = inAppFeedback
        self.biometricLock = biometricLock
        self.localization = localization
        self.paywallTemplates = paywallTemplates
        self.widgets = widgets
        self.questionnaireOnboarding = questionnaireOnboarding
        self.gamification = gamification
        self.aiPro = aiPro
        self.camera = camera
        self.reminders = reminders
        self.swiftDataStore = swiftDataStore
    }
}

public extension FeatureFlags {
    // Defaults are safe; the generator can overwrite values directly.
    static var `default`: FeatureFlags { FeatureFlags() }
}
