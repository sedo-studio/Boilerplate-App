//
//  PaywallGalleryView.swift
//
//  Debug screen that lists all 10 templates and previews each full-screen.
//  Wired into the Test Drive hub behind `featureFlags.paywallTemplates`.
//

import SwiftUI

struct PaywallGalleryView: View {
    @State private var selected: PaywallTemplate?

    var body: some View {
        List {
            Section {
                ForEach(PaywallTemplate.allCases) { template in
                    Button { selected = template } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: template.systemImage)
                                .font(.system(size: 18))
                                .foregroundColor(DS.accent)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.title).appFont(.headline).foregroundColor(.primary)
                                Text(template.blurb).appFont(.footnote).foregroundColor(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("10 Paywall Templates")
            } footer: {
                Text("Tap to preview. Every template is driven by one `PaywallContent` and your DesignSystem theme — customize once, restyle all.")
            }
        }
        .navigationTitle(Text("Paywalls"))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selected) { template in
            PaywallTemplateHost(template: template)
        }
    }
}

#Preview {
    NavigationStack { PaywallGalleryView() }
}
