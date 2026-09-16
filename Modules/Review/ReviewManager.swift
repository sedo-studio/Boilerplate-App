//
//  ReviewManager.swift
//
//  App Store review prompt.
//
//  Note on "showing" a review prompt: `SKStoreReviewController` is a request,
//  not a command. iOS decides whether the sheet actually appears and caps it at
//  roughly three times a year per user, silently ignoring the rest. So the app
//  can ask at exactly the right moment, but it cannot make the prompt appear.
//

import Foundation
import SwiftUI

/// Whether a review has already been asked for on this version. Pure
/// bookkeeping, kept out of `ReviewManager` so it can be tested without
/// involving StoreKit.
enum ReviewPromptPolicy {
    private static let lastVersionKey = "review.lastVersionPrompted"

    static func appVersion(_ bundle: Bundle = .main) -> String {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static func hasAskedThisVersion(defaults: UserDefaults = .standard,
                                    version: String = appVersion()) -> Bool {
        defaults.string(forKey: lastVersionKey) == version
    }

    /// Records that this version has asked. Returns false when it already had,
    /// which is the caller's signal that asking again is pointless.
    @discardableResult
    static func markAsked(defaults: UserDefaults = .standard,
                          version: String = appVersion()) -> Bool {
        guard !hasAskedThisVersion(defaults: defaults, version: version) else { return false }
        defaults.set(version, forKey: lastVersionKey)
        return true
    }
}

@MainActor
final class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    private init() {}

    /// Asks regardless of whether this version already has — the Settings
    /// button, where the user asked for it explicitly.
    func requestReview() {
        RatingService.requestNativeReview()
        ReviewPromptPolicy.markAsked()
    }

    /// Asks only if this version hasn't already. Returns whether it asked.
    @discardableResult
    func requestReviewIfNotYetAsked() -> Bool {
        guard ReviewPromptPolicy.markAsked() else { return false }
        RatingService.requestNativeReview()
        return true
    }
}

/// What happens the moment someone confirms they have their headphones back.
///
/// Both the finder and the radar can end a hunt, and the rule has to be the
/// same in both places, so it lives here rather than in either view.
@MainActor
enum FindWrapUp {
    /// The first confirmed find of each version asks for a review — that is the
    /// moment the app has just worked. After that iOS will not show the prompt
    /// again anyway, so the moment is handed to the alerts subscription
    /// instead, subject to its own cooldown. One ask per find, never two.
    static func perform(container: DIContainer,
                        entitlements: Entitlements,
                        offerAlerts: () -> Void) {
        if container.config.featureFlags.reviewPrompt,
           ReviewManager.shared.requestReviewIfNotYetAsked() {
            container.analytics.track(AnalyticsEvent.reviewPrompted)
            return
        }

        guard container.config.featureFlags.leftBehindAlerts,
              LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: entitlements.hasLeftBehindAlerts)
        else { return }
        offerAlerts()
    }
}
