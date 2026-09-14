//
//  GamificationEngine.swift
//
//  PRO feature — XP, levels, badges & streaks. Modeled on the engine shipped in
//  OverglowAI (GamificationService + StreakService).
//
//  Self-contained: persists to UserDefaults (no SwiftData dependency), so you
//  can delete the `Modules/Gamification` folder + flip `featureFlags.gamification`
//  off to remove the feature entirely.
//
//  Usage from anywhere:
//      GamificationEngine.shared.recordAction(reason: "Task done")   // +XP & streak
//      GamificationEngine.shared.awardXP(50, reason: "Shared app")   // XP only
//

import Foundation
import SwiftUI

// MARK: - Badge

struct GamificationBadge: Identifiable, Sendable, Equatable {
    enum Requirement: Sendable, Equatable {
        case xp(Int)
        case streak(Int)
        case actions(Int)
    }
    let id: String
    let title: String
    let icon: String
    let detail: String
    let requirement: Requirement
}

// MARK: - Catalog (tune your XP curve + badges here)

enum GamificationCatalog {
    /// Cumulative XP required to *reach* a given level. Level 1 = 0 XP,
    /// 2 = 100, 3 = 300, 4 = 600, 5 = 1000 … (a gentle triangular curve).
    static func xpToReach(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 50 * (level - 1) * level
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpToReach(level + 1) <= xp { level += 1 }
        return level
    }

    /// Edit this list to define your app's achievements.
    static let badges: [GamificationBadge] = [
        .init(id: "first_step",   title: "First Step",   icon: "figure.walk",  detail: "Earn your first XP",   requirement: .xp(1)),
        .init(id: "rolling",      title: "Rolling",      icon: "sparkles",     detail: "Reach 100 XP",         requirement: .xp(100)),
        .init(id: "committed",    title: "Committed",    icon: "flame.fill",   detail: "3-day streak",         requirement: .streak(3)),
        .init(id: "on_fire",      title: "On Fire",      icon: "flame.fill",   detail: "7-day streak",         requirement: .streak(7)),
        .init(id: "power_user",   title: "Power User",   icon: "bolt.fill",    detail: "Complete 25 actions",  requirement: .actions(25)),
        .init(id: "legend",       title: "Legend",       icon: "crown.fill",   detail: "Reach Level 10",       requirement: .xp(4500))
    ]
}

// MARK: - Engine

@MainActor
final class GamificationEngine: ObservableObject {
    static let shared = GamificationEngine()

    @Published private(set) var totalXP: Int = 0
    @Published private(set) var totalActions: Int = 0
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var unlockedBadgeIDs: Set<String> = []

    // Transient celebration triggers (observed by the UI overlays).
    @Published var pendingLevelUp: Int?
    @Published var pendingBadge: GamificationBadge?
    @Published var pendingXP: (amount: Int, reason: String)?

    private let defaults: UserDefaults
    private let key = "gamification.state.v1"
    private var lastActivity: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: Derived level info

    var level: Int { GamificationCatalog.level(forXP: totalXP) }
    private var xpAtLevelStart: Int { GamificationCatalog.xpToReach(level) }
    private var xpAtNextLevel: Int { GamificationCatalog.xpToReach(level + 1) }
    var xpIntoLevel: Int { totalXP - xpAtLevelStart }
    var xpNeededThisLevel: Int { max(1, xpAtNextLevel - xpAtLevelStart) }
    var levelProgress: Double { min(1, Double(xpIntoLevel) / Double(xpNeededThisLevel)) }

    // MARK: Mutations

    /// Award XP for a one-off event (no streak change).
    func awardXP(_ amount: Int, reason: String) {
        guard amount != 0 else { return }
        let before = level
        totalXP = max(0, totalXP + amount)
        pendingXP = (amount, reason)
        if level > before { pendingLevelUp = level }
        refreshBadges()
        save()
    }

    /// Record a meaningful action: bumps the action count, updates the daily
    /// streak, and awards XP. Call this from your core "task completed" moments.
    func recordAction(reason: String = "Activity", xp: Int = 10) {
        totalActions += 1
        updateStreak()
        awardXP(xp, reason: reason)   // also refreshes badges + saves
    }

    func reset() {
        totalXP = 0; totalActions = 0; currentStreak = 0; longestStreak = 0
        unlockedBadgeIDs = []; lastActivity = nil
        pendingLevelUp = nil; pendingBadge = nil; pendingXP = nil
        save()
    }

    func isUnlocked(_ badge: GamificationBadge) -> Bool {
        unlockedBadgeIDs.contains(badge.id)
    }

    // MARK: Internals

    private func updateStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = lastActivity {
            let lastDay = cal.startOfDay(for: last)
            let dayDiff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            switch dayDiff {
            case 0:  break                  // already counted today
            case 1:  currentStreak += 1     // consecutive day
            default: currentStreak = 1      // streak broken → restart
            }
        } else {
            currentStreak = 1
        }
        lastActivity = Date()
        longestStreak = max(longestStreak, currentStreak)
    }

    private func meetsRequirement(_ badge: GamificationBadge) -> Bool {
        switch badge.requirement {
        case .xp(let n):      return totalXP >= n
        case .streak(let n):  return longestStreak >= n
        case .actions(let n): return totalActions >= n
        }
    }

    private func refreshBadges() {
        for badge in GamificationCatalog.badges where !unlockedBadgeIDs.contains(badge.id) {
            if meetsRequirement(badge) {
                unlockedBadgeIDs.insert(badge.id)
                pendingBadge = badge
            }
        }
    }

    // MARK: Persistence (UserDefaults JSON)

    private struct State: Codable {
        var totalXP = 0
        var totalActions = 0
        var currentStreak = 0
        var longestStreak = 0
        var unlocked: [String] = []
        var lastActivity: Date?
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let s = try? JSONDecoder().decode(State.self, from: data) else { return }
        totalXP = s.totalXP
        totalActions = s.totalActions
        currentStreak = s.currentStreak
        longestStreak = s.longestStreak
        unlockedBadgeIDs = Set(s.unlocked)
        lastActivity = s.lastActivity
    }

    private func save() {
        let s = State(totalXP: totalXP, totalActions: totalActions,
                      currentStreak: currentStreak, longestStreak: longestStreak,
                      unlocked: Array(unlockedBadgeIDs), lastActivity: lastActivity)
        if let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: key)
        }
    }
}
