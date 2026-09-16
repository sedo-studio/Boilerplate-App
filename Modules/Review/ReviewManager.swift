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

@MainActor
final class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    private init() {}

    /// Asks iOS for the native prompt. Safe to call after any genuine success —
    /// the system does the throttling.
    func requestReview() {
        RatingService.requestNativeReview()
    }
}

/// What happens the moment someone confirms they have their headphones back.
///
/// Both the finder and the radar can end a hunt, and the rule has to be the
/// same in both places, so it lives here rather than in either view.
@MainActor
enum FindWrapUp {
    /// The review ask comes first and fires on every confirmed find: that is
    /// the moment the app has just worked, and iOS throttles the prompt anyway.
    ///
    /// Two modals at once would be a mess, so the alerts subscription is only
    /// offered when the review prompt is switched off. With `reviewPrompt` on —
    /// the default — paywall #2 is reached from Settings instead.
    static func perform(container: DIContainer,
                        entitlements: Entitlements,
                        offerAlerts: () -> Void) {
        if container.config.featureFlags.reviewPrompt {
            container.analytics.track(AnalyticsEvent.reviewPrompted)
            ReviewManager.shared.requestReview()
            return
        }

        guard container.config.featureFlags.leftBehindAlerts,
              LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: entitlements.hasLeftBehindAlerts)
        else { return }
        offerAlerts()
    }
}
