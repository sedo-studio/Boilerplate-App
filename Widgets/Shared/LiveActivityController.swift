//
//  LiveActivityController.swift
//
//  App-side controller to start / end Live Activities. Compiled into the app
//  target (via Widgets/Shared). iOS 16.1+.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
enum LiveActivityController {
    static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static var activeCount: Int {
        Activity<TimerActivityAttributes>.activities.count
    }

    /// Start a countdown Live Activity. Returns false if not permitted.
    @discardableResult
    static func start(title: String, minutes: Int, label: String = "In progress") -> Bool {
        guard areActivitiesEnabled else { return false }
        let attributes = TimerActivityAttributes(title: title)
        let state = TimerActivityAttributes.ContentState(
            endDate: Date().addingTimeInterval(Double(minutes) * 60),
            label: label
        )
        do {
            _ = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            return true
        } catch {
            return false
        }
    }

    static func endAll() async {
        for activity in Activity<TimerActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
