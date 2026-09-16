//
//  LeftBehindPromptPolicy.swift
//
//  Decides when the alerts subscription may be offered after a successful find.
//  The offer only lands if the app has already proved itself, and it never
//  competes with the review prompt for the same moment.
//

import Foundation

enum LeftBehindPromptPolicy {
    private static let findCountKey = "leftbehind.prompt.findCount"
    private static let lastPromptKey = "leftbehind.prompt.lastShown"

    /// Successful finds, counted on this path, before the subscription is
    /// mentioned at all.
    ///
    /// One, not two, because this path does not see every find: the first
    /// confirmed find of each version goes to the review prompt instead
    /// (`FindWrapUp`), and never reaches the counter. So one here means the
    /// offer lands on the user's second find — after the app has worked twice
    /// — and two would have pushed it out to the third.
    private static let minimumFinds = 1
    /// Minimum gap between offers, so a decline is respected.
    private static let cooldown: TimeInterval = 14 * 24 * 60 * 60

    /// Records a confirmed find and reports whether to show the soft prompt.
    static func registerFindAndShouldPrompt(isSubscribed: Bool,
                                            defaults: UserDefaults = .standard) -> Bool {
        let finds = defaults.integer(forKey: findCountKey) + 1
        defaults.set(finds, forKey: findCountKey)

        guard !isSubscribed, finds >= minimumFinds else { return false }
        if let last = defaults.object(forKey: lastPromptKey) as? Date,
           Date().timeIntervalSince(last) < cooldown {
            return false
        }
        defaults.set(Date(), forKey: lastPromptKey)
        return true
    }
}
