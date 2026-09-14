//
//  FeedbackService.swift
//
//  PRO feature — in-app feedback.
//  Self-contained: delete the `Modules/Feedback` folder and flip
//  `featureFlags.inAppFeedback` off to remove this feature entirely.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A single piece of user feedback plus auto-collected device metadata.
public struct FeedbackItem: Codable, Sendable {
    public enum Category: String, Codable, CaseIterable, Sendable {
        case bug, idea, question, praise, other
    }

    public var category: Category
    public var message: String
    public var email: String
    public var appVersion: String
    public var systemVersion: String
    public var deviceModel: String
    public var createdAt: Date

    public init(category: Category, message: String, email: String) {
        self.category = category
        self.message = message
        self.email = email
        self.appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        #if canImport(UIKit)
        self.systemVersion = "iOS " + UIDevice.current.systemVersion
        self.deviceModel = UIDevice.current.model
        #else
        self.systemVersion = ""
        self.deviceModel = ""
        #endif
        self.createdAt = Date()
    }
}

/// Abstraction so you can swap the destination (Supabase, your API, email…)
/// without touching the UI.
public protocol FeedbackService: Sendable {
    func submit(_ item: FeedbackItem) async throws
}

/// Default implementation — works fully offline so the boilerplate runs out of
/// the box. It logs the feedback and stores it in `UserDefaults` so you can
/// inspect submissions during development.
///
/// To send feedback to **Supabase**, create a `feedback` table and replace the
/// body with an insert, e.g.:
///
/// ```swift
/// #if canImport(Supabase)
/// try await SupabaseClientProvider.shared.client
///     .from("feedback")
///     .insert(item)
///     .execute()
/// #endif
/// ```
public struct LocalFeedbackService: FeedbackService {
    public init() {}

    public func submit(_ item: FeedbackItem) async throws {
        // Simulate a short network round-trip for a realistic demo.
        try? await Task.sleep(nanoseconds: 500_000_000)

        AppLogger.log(
            "[Feedback] [\(item.category.rawValue)] \(item.message) — \(item.email.isEmpty ? "no email" : item.email)",
            level: .info
        )

        // Persist locally for development visibility.
        var stored = UserDefaults.standard.array(forKey: "feedback.submissions") as? [String] ?? []
        if let data = try? JSONEncoder().encode(item),
           let json = String(data: data, encoding: .utf8) {
            stored.append(json)
            UserDefaults.standard.set(stored, forKey: "feedback.submissions")
        }
    }
}
