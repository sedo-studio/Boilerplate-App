//
//  RemindersDemoView.swift
//
//  PRO feature demo — request permission, schedule daily/streak reminders, and
//  fire a 5-second test notification.
//

import SwiftUI
import UserNotifications

struct RemindersDemoView: View {
    @ObservedObject private var scheduler = ReminderScheduler.shared
    @State private var time = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()

    var body: some View {
        List {
            Section("Permission") {
                HStack {
                    Label("Status", systemImage: "bell.badge")
                    Spacer()
                    Text(statusText)
                        .foregroundColor(scheduler.authorization == .authorized ? DS.success : .secondary)
                }
                if scheduler.authorization != .authorized {
                    Button { Task { await scheduler.requestAuthorization() } } label: {
                        Label("Request permission", systemImage: "hand.raised")
                    }
                }
            }

            Section("Daily reminder") {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                Button {
                    let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                    Task { await scheduler.scheduleDaily(hour: c.hour ?? 9, minute: c.minute ?? 0) }
                } label: { Label("Schedule daily reminder", systemImage: "alarm") }
                Button {
                    Task { await scheduler.scheduleStreakReminder() }
                } label: { Label("Schedule streak reminder (8 PM)", systemImage: "flame") }
            }

            Section {
                Button {
                    Task { await scheduler.scheduleTest(after: 5) }
                } label: { Label("Notify me in 5 seconds", systemImage: "timer") }
            } header: {
                Text("Test")
            } footer: {
                Text("Background the app to see the banner — foreground delivery depends on your UNUserNotificationCenterDelegate.")
            }

            Section {
                HStack {
                    Label("Pending", systemImage: "tray.full")
                    Spacer()
                    Text("\(scheduler.pendingCount)").foregroundColor(.secondary)
                }
                Button(role: .destructive) { scheduler.cancelAll() } label: {
                    Label("Cancel all", systemImage: "trash")
                }
            }
        }
        .navigationTitle(Text("Reminders"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await scheduler.refresh() }
    }

    private var statusText: String {
        switch scheduler.authorization {
        case .authorized:   return "Authorized"
        case .denied:       return "Denied"
        case .provisional:  return "Provisional"
        case .ephemeral:    return "Ephemeral"
        default:            return "Not determined"
        }
    }
}

#Preview {
    NavigationStack { RemindersDemoView() }
}
