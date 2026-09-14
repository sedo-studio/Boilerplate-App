//
//  GamificationDemoView.swift
//
//  PRO feature demo — exercises the gamification engine: award XP, build a
//  streak, unlock badges, and watch the celebration overlays fire.
//

import SwiftUI

struct GamificationDemoView: View {
    @ObservedObject private var engine = GamificationEngine.shared
    private let columns = [GridItem(.adaptive(minimum: 84), spacing: DS.Spacing.md)]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                GamificationHeaderCard()

                VStack(spacing: DS.Spacing.sm) {
                    actionRow("Complete a task", "+10 XP · advances streak", "checkmark.circle.fill") {
                        engine.recordAction(reason: "Task done")
                    }
                    actionRow("Big win", "+100 XP", "star.fill") {
                        engine.awardXP(100, reason: "Big win")
                    }
                    actionRow("Reset progress", "clear XP, streak & badges", "arrow.counterclockwise", role: .destructive) {
                        engine.reset()
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Badges (\(engine.unlockedBadgeIDs.count)/\(GamificationCatalog.badges.count))")
                        .appFont(.headline)
                    LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                        ForEach(GamificationCatalog.badges) { badge in
                            GamificationBadgeCell(badge: badge, unlocked: engine.isUnlocked(badge))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .padding(DS.Spacing.lg)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Text("Gamification"))
        .navigationBarTitleDisplayMode(.inline)
        .gamificationCelebrations()
    }

    private func actionRow(_ title: String, _ subtitle: String, _ icon: String,
                           role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon).frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).appFont(.body).foregroundColor(.primary)
                    Text(subtitle).appFont(.caption).foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .tint(role == .destructive ? .red : DS.accent)
    }
}

#Preview {
    NavigationStack { GamificationDemoView() }
}
