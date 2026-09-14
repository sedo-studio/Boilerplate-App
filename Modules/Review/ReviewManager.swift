//
//  ReviewManager.swift
//
//  PRO feature — App Store review prompt.
//  Counts "significant events" and asks for a review at the right moment
//  (Apple's native prompt is itself rate-limited by the system).
//
//  Self-contained: delete the `Modules/Review` folder, remove the
//  `requestNativeReview()` helper from `RatingService.swift`, and flip
//  `featureFlags.reviewPrompt` off to remove this feature entirely.
//

import Foundation
import SwiftUI

@MainActor
final class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    /// Number of significant events before we ask for a review.
    let threshold: Int

    private let eventCountKey = "review.significantEvents"
    private let lastVersionKey = "review.lastVersionPrompted"
    private let defaults: UserDefaults

    init(threshold: Int = 3, defaults: UserDefaults = .standard) {
        self.threshold = threshold
        self.defaults = defaults
    }

    /// Current progress toward the next prompt (for display/testing).
    var significantEvents: Int { defaults.integer(forKey: eventCountKey) }

    /// Call this after a meaningful action (e.g. the user finished a core task).
    /// When the threshold is reached, the native review prompt is requested.
    func registerSignificantEvent() {
        let count = defaults.integer(forKey: eventCountKey) + 1
        defaults.set(count, forKey: eventCountKey)
        if count >= threshold {
            requestReviewIfAppropriate()
        }
    }

    /// Requests the native prompt at most once per app version.
    func requestReviewIfAppropriate() {
        let version = Self.appVersion
        guard defaults.string(forKey: lastVersionKey) != version else { return }
        RatingService.requestNativeReview()
        defaults.set(version, forKey: lastVersionKey)
        defaults.set(0, forKey: eventCountKey)
    }

    /// Forces the native prompt regardless of throttling (useful for the demo).
    func requestNativeReviewNow() {
        RatingService.requestNativeReview()
    }

    /// Resets the local counters (useful for the demo / QA).
    func reset() {
        defaults.set(0, forKey: eventCountKey)
        defaults.removeObject(forKey: lastVersionKey)
    }

    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
