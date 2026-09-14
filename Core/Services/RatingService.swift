//
//  RatingService.swift
//

import Foundation
import SwiftUI
import StoreKit
// Pure SwiftUI/URL approach; caller opens URLs via openURL

public enum RatingService {
    /// Builds the App Store write-review URL for a given app id.
    public static func appReviewURL(appId: String) -> URL? {
        // Use itms-apps scheme to jump directly to App Store
        URL(string: "itms-apps://apps.apple.com/app/id\(appId)?action=write-review")
    }

    /// Returns the best review URL (itms-apps if available; otherwise web).
    public static func bestReviewURL(appId: String) -> URL? {
        appReviewURL(appId: appId) ?? URL(string: "https://apps.apple.com/app/id\(appId)?action=write-review")
    }

    /// Triggers Apple's native in-app review prompt (the system rate-limits how
    /// often this actually appears, so it's safe to call after a key action).
    /// Used by `ReviewManager` (see `Modules/Review`).
    @MainActor
    public static func requestNativeReview() {
        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
        #endif
    }
}
