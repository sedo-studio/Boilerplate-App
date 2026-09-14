//
//  TheSwiftKitWidgets.swift
//
//  The widget extension's @main bundle: a home/lock-screen status widget plus a
//  Live Activity (Lock Screen + Dynamic Island). This file is compiled ONLY into
//  the widget extension target.
//
//  To share real data with the home-screen widget, add an App Group and read
//  shared UserDefaults in StatusProvider.getTimeline (see comment below).
//

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Static (home / lock screen) widget

struct StatusEntry: TimelineEntry {
    let date: Date
    let title: String
    let value: String
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), title: "Swift Kit Pro", value: "Ready")
    }
    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: Date(), title: "Swift Kit Pro", value: "Ready"))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        // Real apps: read shared values from an App Group here, e.g.
        //   let shared = UserDefaults(suiteName: "group.com.yourapp")
        let entry = StatusEntry(date: Date(), title: "Swift Kit Pro", value: "Today")
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct StatusWidgetView: View {
    var entry: StatusEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").foregroundStyle(.orange)
                Text(entry.title).font(.caption).bold().lineLimit(1)
                Spacer()
            }
            Spacer()
            Text(entry.value).font(.title2).bold()
            Text(entry.date, style: .time).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetContainerBackground()
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TheSwiftKitStatusWidget", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Status")
        .description("A quick status from your app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// iOS 17 requires `containerBackground` for widgets; this keeps iOS 16 working too.
extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.padding().containerBackground(.fill.tertiary, for: .widget)
        } else {
            self.padding().background(Color(.systemBackground))
        }
    }
}

// MARK: - Live Activity (Lock Screen + Dynamic Island)

@available(iOS 16.1, *)
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            HStack {
                Label(context.attributes.title, systemImage: "timer")
                Spacer()
                Text(context.state.endDate, style: .timer).monospacedDigit().bold()
            }
            .padding()
            .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.title, systemImage: "timer")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endDate, style: .timer).monospacedDigit().frame(width: 60)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.label).font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(context.state.endDate, style: .timer).monospacedDigit().frame(width: 44)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

// MARK: - Bundle entry point

@main
struct TheSwiftKitWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        if #available(iOS 16.1, *) {
            TimerLiveActivity()
        }
    }
}
