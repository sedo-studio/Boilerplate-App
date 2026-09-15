//
//  RadarView.swift
//
//  The paid screen: a soft glowing dial driven by signal strength.
//
//  Deliberately not a compass. Nothing here points anywhere — the glow grows
//  and warms as the signal strengthens, which is the honest visual form of
//  "getting warmer". The colour ramp runs cool blue → coral for exactly that
//  reason.
//

import SwiftUI

struct RadarView: View {
    /// Opened as a timed glimpse for someone who hasn't unlocked it.
    var isPreview: Bool = false

    @Environment(\.container) private var container
    @EnvironmentObject private var entitlements: Entitlements
    @EnvironmentObject private var router: AppRouter
    @StateObject private var finder = BluetoothFinder.shared

    @State private var pulse = false
    @State private var openedAt = Date()
    @State private var showAlertsPaywall = false
    @State private var showRadarPaywall = false
    @State private var previewTimer: Task<Void, Never>?
    @State private var didStartLiveCountdown = false

    /// Seconds of *live signal* the glimpse runs for. Counted from the first
    /// real reading, not from screen-open: the smoother needs four samples
    /// before it will say warmer or colder, so a timer that started on appear
    /// would mostly show the warm-up state.
    private let previewSeconds: Double = 4
    /// Backstop for a device that never answers, so nobody is stranded on a
    /// dead dial waiting for a paywall that never comes.
    private let previewCapSeconds: Double = 9

    /// True while this is still a glimpse. Buying flips it off immediately.
    private var isGlimpse: Bool { isPreview && !entitlements.isRadarUnlocked }

    var body: some View {
        ZStack {
            // The dial is the light source on this screen, so the drifting
            // background is turned down behind it.
            AnimatedBackground(intensity: 0.45).ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                Spacer(minLength: 0)

                RadarDial(intensity: intensity,
                          tint: tint,
                          trend: finder.trend,
                          isLive: finder.hasLiveReading,
                          pulse: $pulse)

                VStack(spacing: DS.Spacing.sm) {
                    if isGlimpse {
                        Text("radar.preview.chip")
                            .appFont(.captionBold)
                            .foregroundStyle(DS.accent)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(Capsule().fill(DS.accent.opacity(0.15)))
                    } else {
                        DSEyebrow(finder.hasLiveReading ? "radar.eyebrow.live" : "radar.eyebrow.warmup")
                    }

                    if finder.hasLiveReading {
                        Text(LocalizedStringKey(finder.proximity.titleKey))
                            .appFont(.largeTitle)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(LocalizedStringKey(finder.proximity.detailKey))
                            .appFont(.body)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("radar.warmup.title")
                            .appFont(.largeTitle)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("radar.warmup.body")
                            .appFont(.body)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .animation(.easeInOut(duration: DS.Motion.slow), value: finder.proximity)

                Spacer(minLength: 0)

                VStack(spacing: DS.Spacing.md) {
                    if isGlimpse {
                        Text("radar.preview.note")
                            .appFont(.footnote)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Button("radar.gotthem") { confirmRecovered() }
                            .buttonStyle(DSPrimaryButtonStyle())
                    }

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
        .sheet(isPresented: $showRadarPaywall, onDismiss: handleRadarPaywallDismiss) {
            // Only claim they watched it work if a real reading actually
            // arrived. On the timeout path they saw a dim, silent dial.
            RadarUnlockPaywallView(followsPreview: didStartLiveCountdown)
        }
        .onAppear {
            openedAt = Date()
            pulse = true
            finder.startProximityTracking()
            beginGlimpse()
        }
        .onChange(of: finder.hasLiveReading) { isLive in
            // The glimpse is measured in seconds of real signal.
            guard isGlimpse, isLive, !didStartLiveCountdown else { return }
            didStartLiveCountdown = true
            schedulePaywall(after: previewSeconds)
        }
        .onDisappear {
            previewTimer?.cancel()
            previewTimer = nil
            finder.stopProximityTracking()
        }
    }

    /// 0 (faint) → 1 (very close). Held low until a real reading lands.
    private var intensity: Double {
        finder.hasLiveReading ? finder.proximity.intensity : 0.12
    }

    private var tint: Color {
        DS.Colors.blend(DS.cool, DS.warm, amount: finder.hasLiveReading ? finder.proximity.intensity : 0)
    }

    // MARK: - Glimpse

    private func beginGlimpse() {
        guard isGlimpse else { return }
        container.analytics.track(AnalyticsEvent.radarPreviewShown)
        schedulePaywall(after: previewCapSeconds)
    }

    private func schedulePaywall(after seconds: Double) {
        previewTimer?.cancel()
        previewTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, isGlimpse else { return }
            showRadarPaywall = true
        }
    }

    /// Bought → stay on the now-unlocked radar. Declined → back to the finder,
    /// rather than leaving them parked on a screen they can't use.
    private func handleRadarPaywallDismiss() {
        if entitlements.isRadarUnlocked {
            previewTimer?.cancel()
            previewTimer = nil
        } else {
            router.pop()
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
    let intensity: Double
    let tint: Color
    let trend: ProximityTrend
    let isLive: Bool
    @Binding var pulse: Bool

    private let size: CGFloat = 320
    private let ringDiameter: CGFloat = 196

    /// Closer devices pulse faster — the feedback loop that makes sweeping a
    /// room feel responsive.
    private var pulseDuration: Double { 2.6 - 1.4 * intensity }

    var body: some View {
        ZStack {
            // Outer halo — the soft bloom that carries most of the colour.
            Circle()
                .fill(
                    RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0)],
                                   center: .center, startRadius: 0, endRadius: size / 2)
                )
                .frame(width: size, height: size)
                .blur(radius: 45)
                .scaleEffect(0.75 + 0.4 * intensity)

            // Expanding rings, blurred so they read as light rather than line art.
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(tint.opacity(0.4), lineWidth: 1.5)
                    .frame(width: ringDiameter, height: ringDiameter)
                    .blur(radius: 2)
                    .scaleEffect(pulse ? 1.45 : 0.55)
                    .opacity(pulse ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: pulseDuration)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * pulseDuration / 3),
                        value: pulse
                    )
            }

            // The dial edge.
            Circle()
                .strokeBorder(
                    AngularGradient(colors: [tint.opacity(0.9), tint.opacity(0.15), tint.opacity(0.9)],
                                    center: .center),
                    lineWidth: 1.5
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .blur(radius: 0.5)
                .shadow(color: tint.opacity(0.6), radius: 18)

            // Core orb — grows and brightens with proximity.
            Circle()
                .fill(
                    RadialGradient(colors: [.white.opacity(0.9), tint.opacity(0.8), tint.opacity(0)],
                                   center: .center, startRadius: 1, endRadius: 80)
                )
                .frame(width: 150, height: 150)
                .blur(radius: 14)
                .scaleEffect(0.45 + 0.65 * intensity)
                .shadow(color: tint.opacity(0.7), radius: 30)

            if isLive {
                VStack(spacing: DS.Spacing.xs) {
                    Image(systemName: trend.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                    Text(LocalizedStringKey(trend.titleKey))
                        .appFont(.footnoteSemibold)
                }
                .foregroundStyle(.white)
                .shadow(color: tint.opacity(0.8), radius: 12)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: DS.Motion.slow), value: intensity)
        .animation(.easeInOut(duration: DS.Motion.slow), value: tint)
        .accessibilityElement()
        .accessibilityLabel(Text(LocalizedStringKey(trend.titleKey)))
    }
}

struct RadarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { RadarView() }
            .environmentObject(AppRouter())
            .environmentObject(Entitlements(purchases: LocalPurchasesService(), flags: .default))
            .preferredColorScheme(.dark)
    }
}
