//
//  LanguagePickerView.swift
//
//  PRO feature — in-app language picker. Pushed from Settings and the demo hub.
//

import SwiftUI

struct LanguagePickerView: View {
    @StateObject private var manager = LocalizationManager.shared

    var body: some View {
        List {
            Section("language.choose") {
                ForEach(LocalizationManager.supported, id: \.code) { lang in
                    Button {
                        manager.setLanguage(lang.code)
                    } label: {
                        HStack {
                            Text(lang.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if manager.languageCode == lang.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DS.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                previewRow("home.title")
                previewRow("settings.title")
                previewRow("auth.signin")
                previewRow("paywall.continue")
                previewRow("feedback.submit")
            } header: {
                Text("language.preview")
            } footer: {
                Text("language.footer")
            }
        }
        .navigationTitle(Text("language.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Shows a key alongside its live-resolved translation. Uses `.localized`
    /// (NSLocalizedString) so it updates immediately when the language changes.
    private func previewRow(_ key: String) -> some View {
        HStack {
            Text(verbatim: key)
                .appFont(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(verbatim: key.localized)
                .appFont(.callout)
        }
    }
}

#Preview {
    NavigationStack { LanguagePickerView() }
}
