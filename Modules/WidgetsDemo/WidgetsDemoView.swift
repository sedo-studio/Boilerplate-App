//
//  WidgetsDemoView.swift
//
//  PRO feature demo (app side) — explains the home-screen widget and starts/ends
//  the Live Activity. The widget extension itself lives in `Widgets/`.
//
//  Self-contained: delete `Modules/WidgetsDemo` + the `Widgets/` folder + the
//  widget target/embed in project.yml + flip `featureFlags.widgets` off.
//

import SwiftUI

struct WidgetsDemoView: View {
    @State private var message: String?

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Image(systemName: "rectangle.3.group.fill")
                        .foregroundColor(DS.accent).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Home & Lock-Screen Widget").appFont(.body)
                        Text("Long-press the Home Screen → ➕ → search “Swift Kit Pro” to add the Status widget (small & medium).")
                            .appFont(.footnote).foregroundColor(.secondary)
                    }
                }
            } header: { Text("Widgets") }

            Section {
                if #available(iOS 16.1, *) {
                    Button { startLiveActivity() } label: {
                        Label("Start Live Activity (10 min)", systemImage: "play.circle")
                    }
                    Button(role: .destructive) { endLiveActivity() } label: {
                        Label("End Live Activities", systemImage: "stop.circle")
                    }
                    if let message {
                        Text(message).appFont(.footnote).foregroundColor(.secondary)
                    }
                } else {
                    Text("Live Activities require iOS 16.1 or later.")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Live Activity / Dynamic Island")
            } footer: {
                Text("Best experienced on a real device — starts a countdown that appears on the Lock Screen and in the Dynamic Island.")
            }
        }
        .navigationTitle(Text("Widgets & Live Activities"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @available(iOS 16.1, *)
    private func startLiveActivity() {
        let ok = LiveActivityController.start(title: "Focus Session", minutes: 10)
        message = ok
            ? "Live Activity started — check the Lock Screen / Dynamic Island."
            : "Couldn't start. Enable Live Activities in Settings, or try a real device."
    }

    @available(iOS 16.1, *)
    private func endLiveActivity() {
        Task {
            await LiveActivityController.endAll()
            message = "Ended all Live Activities."
        }
    }
}

#Preview {
    NavigationStack { WidgetsDemoView() }
}
