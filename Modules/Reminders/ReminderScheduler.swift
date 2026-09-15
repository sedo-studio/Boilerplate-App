//
//  ReminderScheduler.swift
//
//  Local-notification plumbing. Deliberately generic — it knows how to ask for
//  permission and deliver a notification, and nothing about headphones.
//  `Modules/LeftBehind` decides when to call it.
//
//  Local notifications need no Info.plist key; the system prompt appears on the
//  first `requestAuthorization`.
//

import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class ReminderScheduler: NSObject, ObservableObject {
    static let shared = ReminderScheduler()

    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        Task { await refresh() }
    }

    /// Must run before launch finishes so foreground alerts are presented.
    func installDelegate() {
        center.delegate = self
    }

    var isAuthorized: Bool {
        authorization == .authorized || authorization == .provisional || authorization == .ephemeral
    }

    func refresh() async {
        let settings = await center.notificationSettings()
        authorization = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refresh()
        return granted
    }

    /// Schedules a one-off notification. Re-using an identifier replaces the
    /// pending request, which is how a re-armed alert supersedes the last one.
    func schedule(id: String, title: String, body: String, after seconds: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

extension ReminderScheduler: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
