//
//  RadarView.swift
//
//  The paid screen. A pulsing radar driven by signal strength — deliberately
//  not a compass. The ring grows as the signal strengthens and the copy says
//  "warmer"/"colder", because that is genuinely all RSSI can tell us.
//

import SwiftUI

struct RadarView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var entitlements: Entitlements
    @StateObject private var finder = BluetoothFinder.shared

    @State private var pulse = false
    @State private var openedAt = Date()
    @State private var showAlertsPaywall = false

    var body: some View {
        ZStack {
            AnimatedBackground().ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                Spacer(minLength: 0)

                RadarDial(intensity: finder.hasLiveReading ? finder.proximity.intensity : 0.15,
                          isLive: finder.hasLiveReading,
                          pulse: $pulse)

                VStack(spacing: DS.Spacing.sm) {
                    if finder.hasLiveReading {
                        Text(LocalizedStringKey(finder.proximity.titleKey))
                            .appFont(.title2)
                        Label(LocalizedStringKey(finder.trend.titleKey), systemImage: finder.trend.systemImage)
                            .appFont(.headline)
                            .foregroundStyle(trendColor)
                        Text(LocalizedStringKey(finder.proximity.detailKey))
                            .appFont(.body)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("radar.warmup.title").appFont(.title3)
                        Text("radar.warmup.body")
                            .appFont(.body)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .animation(.easeInOut(duration: DS.Motion.normal), value: finder.proximity)
                .animation(.easeInOut(duration: DS.Motion.normal), value: finder.trend)

                Spacer(minLength: 0)

                VStack(spacing: DS.Spacing.md) {
                    Button("radar.gotthem") { confirmRecovered() }
                        .buttonStyle(DSPrimaryButtonStyle())

                    Text("radar.disclaimer")
                        .appFont(.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
        }
        .navigationTitle(Text("radar.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAlertsPaywall) { LeftBehindPaywallView() }
        .onAppear {
            openedAt = Date()
            pulse = true
            finder.startProximityTracking()
        }
        .onDisappear { finder.stopProximityTracking() }
    }

    private var trendColor: Color {
        switch finder.trend {
        case .warmer: return DS.success
        case .colder: return DS.warning
        case .steady: return DS.Colors.textSecondary
        }
    }

    private func confirmRecovered() {
        container.analytics.track(AnalyticsEvent.findSucceeded, properties: [
            AnalyticsProperty.source: "radar",
            AnalyticsProperty.proximity: finder.proximity.analyticsValue,
            AnalyticsProperty.durationSeconds: String(Int(Date().timeIntervalSince(openedAt)))
        ])
        finder.stopProximityTracking()

        // One ask per find: the subscription offer, or the review prompt.
        let offersAlerts = container.config.featureFlags.leftBehindAlerts
            && LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: entitlements.hasLeftBehindAlerts)
        if offersAlerts {
            showAlertsPaywall = true
        } else if container.config.featureFlags.reviewPrompt {
            ReviewManager.shared.registerSignificantEvent()
        }
    }
}

// MARK: - Dial

private struct RadarDial: View {
    /// 0 → far, 1 → very close.
    let intensity: Double
    let isLive: Bool
    @Binding var pulse: Bool

    private var ringCount: Int { 3 }

    var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { index in
                Circle()
                    .stroke(DS.accent.opacity(0.28), lineWidth: 2)
                    .scaleEffect(pulse ? 1.0 : 0.25)
                    .opacity(pulse ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: pulseDuration)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * pulseDuration / Double(ringCount)),
                        value: pulse
                    )
            }

            Circle()
                .fill(
                    RadialGradient(colors: [DS.accent.opacity(0.55), DS.accent.opacity(0.05)],
                                   center: .center,
                                   startRadius: 4,
                                   endRadius: 130)
                )
                .scaleEffect(0.35 + 0.65 * intensity)
                .animation(.easeInOut(duration: 0.6), value: intensity)

            Image(systemName: "airpodspro")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(isLive ? DS.accent : DS.Colors.textTertiary)
        }
        .frame(width: 260, height: 260)
        .accessibilityHidden(true)
    }

    /// Closer devices pulse faster — the "hotter" feedback loop.
    private var pulseDuration: Double { 2.2 - 1.2 * intensity }
}

struct RadarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { RadarView() }
            .environmentObject(Entitlements(purchases: LocalPurchasesService(), flags: .default))
    }
}
