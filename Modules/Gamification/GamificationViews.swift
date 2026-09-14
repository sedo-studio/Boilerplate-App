//
//  GamificationViews.swift
//
//  Reusable, DS-themed gamification UI + a `.gamificationCelebrations()` overlay
//  modifier you can attach to any screen to show XP toasts, level-ups & badges.
//

import SwiftUI

// MARK: - Level ring

struct GamificationLevelRing: View {
    var level: Int
    var progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color(.systemGray5), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [DS.accent, DS.primary], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("LVL").appFont(.caption2).foregroundColor(.secondary)
                Text("\(level)").appFont(.title2)
            }
        }
        .frame(width: 76, height: 76)
        .animation(.easeInOut(duration: DS.Motion.normal), value: progress)
    }
}

// MARK: - Header card (level + XP + streak)

struct GamificationHeaderCard: View {
    @ObservedObject private var engine = GamificationEngine.shared

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            GamificationLevelRing(level: engine.level, progress: engine.levelProgress)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("\(engine.totalXP) XP").appFont(.title3)
                Text("\(engine.xpIntoLevel)/\(engine.xpNeededThisLevel) to level \(engine.level + 1)")
                    .appFont(.caption).foregroundColor(.secondary)
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "flame.fill").foregroundColor(.orange)
                    Text("\(engine.currentStreak)-day streak").appFont(.footnoteSemibold)
                    if engine.longestStreak > engine.currentStreak {
                        Text("· best \(engine.longestStreak)").appFont(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Badge cell

struct GamificationBadgeCell: View {
    let badge: GamificationBadge
    let unlocked: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(unlocked ? DS.accent.opacity(0.15) : Color(.systemGray6))
                    .frame(width: 60, height: 60)
                Image(systemName: unlocked ? badge.icon : "lock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(unlocked ? DS.accent : Color(.tertiaryLabel))
            }
            Text(badge.title)
                .appFont(.caption)
                .foregroundColor(unlocked ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .opacity(unlocked ? 1 : 0.7)
    }
}

// MARK: - XP toast

struct XPToastView: View {
    let amount: Int
    let reason: String
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "bolt.fill")
            Text("+\(amount) XP · \(reason)").appFont(.footnoteSemibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(Capsule().fill(DS.accent))
        .shadow(color: DS.accent.opacity(0.4), radius: 10, x: 0, y: 4)
        .padding(.top, DS.Spacing.sm)
    }
}

// MARK: - Celebration overlay (level-up / badge)

struct GamificationCelebrationOverlay: View {
    let icon: String
    let title: String
    let subtitle: String
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: dismiss)
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(LinearGradient(colors: [DS.accent, DS.primary], startPoint: .top, endPoint: .bottom))
                Text(title).appFont(.title)
                Text(subtitle).appFont(.subheadline).foregroundColor(.secondary)
            }
            .padding(DS.Spacing.xl)
            .background(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous).fill(Color(.systemBackground)))
            .shadow(radius: 24)
        }
        .transition(.opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { dismiss() } }
        }
    }
}

// MARK: - Celebrations modifier (attach anywhere)

private struct GamificationCelebrationsModifier: ViewModifier {
    @ObservedObject private var engine = GamificationEngine.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let xp = engine.pendingXP {
                    XPToastView(amount: xp.amount, reason: xp.reason)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                withAnimation { engine.pendingXP = nil }
                            }
                        }
                }
            }
            .overlay {
                if let level = engine.pendingLevelUp {
                    GamificationCelebrationOverlay(icon: "star.circle.fill",
                                                   title: "Level \(level)!",
                                                   subtitle: "You leveled up") { engine.pendingLevelUp = nil }
                } else if let badge = engine.pendingBadge {
                    GamificationCelebrationOverlay(icon: badge.icon,
                                                   title: badge.title,
                                                   subtitle: "Badge unlocked") { engine.pendingBadge = nil }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.pendingXP?.amount)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.pendingLevelUp)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.pendingBadge)
    }
}

extension View {
    /// Shows XP toasts, level-up and badge celebrations whenever the engine fires
    /// them. Attach once near the top of a screen (or the app root).
    func gamificationCelebrations() -> some View {
        modifier(GamificationCelebrationsModifier())
    }
}
