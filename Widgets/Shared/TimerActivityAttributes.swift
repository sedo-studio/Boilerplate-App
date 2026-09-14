//
//  TimerActivityAttributes.swift
//
//  Shared between the app (starts/updates the activity) and the widget extension
//  (renders it). Lives in Widgets/Shared, which is compiled into BOTH targets.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var endDate: Date
        public var label: String
        public init(endDate: Date, label: String) {
            self.endDate = endDate
            self.label = label
        }
    }

    public var title: String
    public init(title: String) { self.title = title }
}
