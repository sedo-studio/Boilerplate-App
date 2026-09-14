//
//  ReminderScheduler.swift
//
//  PRO feature — local reminder / notification scheduling. Modeled on the
//  ReminderService shipped in OverglowAI (daily reminders + streak nudges).
//
//  Self-contained: uses UNUserNotificationCenter directly (no push/server needed).
//  Delete `Modules/Reminders` + flip `featureFlags.reminders` off to remove.
//
//  NOTE: local notifications don't need any Info.plist key — the system prompt
//  is shown on first `requestAuthorization`.
//

import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class ReminderScheduler: ObservableObject {
    static let shared = ReminderScheduler()

    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var pendingCount: Int = 0

    private let center = UNUserNotificationCenter.current()
    private let dailyID = "reminder.daily"
    private let streakID = "reminder.streak"

    /// Refresh the published authorization status + pending request count.
    func refresh() async {
        let settings = await center.notificationSettings()
        authorization = settings.authorizationStatus
        pendingCount = await center.pendingNotificationRequests().count
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refresh()
        return granted
    }

    /// A repeating daily reminder at a given wall-clock time.
    func scheduleDaily(hour: Int, minute: Int,
                       title: String = "Time to check in 👋",
                       body: String = "A minute today keeps your progress going.") async {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        await add(id: dailyID, title: title, body: body, trigger: trigger)
    }

    /// A streak-protection nudge (pairs with the Gamification engine).
    func scheduleStreakReminder(hour: Int = 20) async {
        var comps = DateComponents()
        comps.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        await add(id: streakID,
                  title: "Don't break your streak! 🔥",
                  body: "Open the app to keep your streak alive.",
                  trigger: trigger)
    }

    /// One-off test notification, handy for QA.
    func scheduleTest(after seconds: TimeInterval = 5) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        await add(id: "reminder.test.\(UUID().uuidString)",
                  title: "Test reminder ✅",
                  body: "This local notification was scheduled \(Int(seconds))s ago.",
                  trigger: trigger)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        pendingCount = 0
    }

    private func add(id: String, title: String, body: String, trigger: UNNotificationTrigger) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
        await refresh()
    }
}
