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
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var entitlements: Entitlements
    @EnvironmentObject private var router: AppRouter
    @StateObject private var finder = BluetoothFinder.shared

    @AppStorage("haptics.proximity") private var hapticsEnabled: Bool = true

    @State private var pulse = false
    @State private var openedAt = Date()
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
                    } else if finder.proximityUnavailable {
                        Text("radar.nosignal.title")
                            .appFont(.title2)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("radar.nosignal.body")
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

                    #if DEBUG
                    // "No signal" has several different causes; this says which.
                    Text(verbatim: "\(finder.trackedDevice?.name.isEmpty == false ? finder.trackedDevice!.name : "(unnamed)") · \(finder.diagnostics)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                    #endif
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
        }
        .navigationTitle(Text("radar.title"))
        .navigationBarTitleDisplayMode(.inline)
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
            syncHaptics()
            // The glimpse is measured in seconds of real signal.
            guard isGlimpse, isLive, !didStartLiveCountdown else { return }
            didStartLiveCountdown = true
            schedulePaywall(after: previewSeconds)
        }
        .onChange(of: finder.proximity) { _ in
            ProximityHaptics.shared.update(intensity: intensity)
        }
        .onChange(of: hapticsEnabled) { _ in syncHaptics() }
        .onChange(of: scenePhase) { phase in
            // Never keep ticking in someone's pocket.
            phase == .active ? syncHaptics() : ProximityHaptics.shared.stop()
        }
        .onDisappear {
            previewTimer?.cancel()
            previewTimer = nil
            finder.stopProximityTracking()
            ProximityHaptics.shared.stop()
        }
    }

    /// 0 (faint) → 1 (very close). Held low until a real reading lands.
    private var intensity: Double {
        finder.hasLiveReading ? finder.proximity.intensity : 0.12
    }

    private var tint: Color {
        DS.Colors.temperature(finder.hasLiveReading ? finder.proximity.intensity : 0)
    }

    /// Ticking only earns its keep once there is a real reading to tick about.
    private func syncHaptics() {
        guard hapticsEnabled, finder.hasLiveReading else {
            ProximityHaptics.shared.stop()
            return
        }
        ProximityHaptics.shared.update(intensity: intensity)
        ProximityHaptics.shared.start()
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
        // Hand back to the finder, which shows the wrap-up and runs the
        // review ask. Staying on a frozen dial was the bug: tapping the button
        // stopped tracking and nothing else visibly happened.
        finder.markRecovered()
        router.pop()
    }
}

// MARK: - Dial

private struct RadarDial: View {
    let intensity: Double
    let tint: Color
    let trend: ProximityTrend
    let isLive: Bool
    @Binding var pulse: Bool

    /// Light rolls around the rim continuously. Deliberately a symmetric
    /// shimmer rather than a sweeping radar line — a line that travels round
    /// the dial reads as "scanning in that direction", which is precisely the
    /// impression this app must never give.
    @State private var spin = false

    private let size: CGFloat = 320
    private let ringDiameter: CGFloat = 200
    private let orbDiameter: CGFloat = 150

    /// Closer devices pulse faster — the feedback loop that makes sweeping a
    /// room feel responsive.
    private var pulseDuration: Double { 2.6 - 1.4 * intensity }
    private var orbScale: CGFloat { 0.62 + 0.38 * intensity }

    var body: some View {
        ZStack {
            bloom
            if isLive {
                ProximityMotes(intensity: intensity, trend: trend, tint: tint)
                    .frame(width: size, height: size)
            }
            pulseRings
            dialEdge
            orb
            if isLive { label }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: DS.Motion.slow), value: intensity)
        .animation(.easeInOut(duration: DS.Motion.slow), value: tint)
        .onAppear { spin = true }
        .accessibilityElement()
        .accessibilityLabel(Text(LocalizedStringKey(trend.titleKey)))
    }

    /// Soft bloom that throws the dial's colour onto the background.
    private var bloom: some View {
        Circle()
            .fill(RadialGradient(colors: [tint.opacity(0.5), tint.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .blur(radius: 45)
            .scaleEffect(0.75 + 0.4 * intensity)
    }

    private var pulseRings: some View {
        ForEach(0..<3, id: \.self) { index in
            Circle()
                .strokeBorder(tint.opacity(0.35), lineWidth: 1.5)
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
    }

    private var dialEdge: some View {
        Circle()
            .strokeBorder(
                AngularGradient(colors: [tint.opacity(0.1), tint.opacity(0.85),
                                         tint.opacity(0.1), tint.opacity(0.85),
                                         tint.opacity(0.1)],
                                center: .center),
                lineWidth: 1.5
            )
            .frame(width: ringDiameter, height: ringDiameter)
            .blur(radius: 0.6)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 14).repeatForever(autoreverses: false), value: spin)
            .shadow(color: tint.opacity(0.5), radius: 16)
    }

    /// A lit sphere rather than a flat blob: the fill is offset toward the top
    /// left so one side catches the light, a specular highlight sits on that
    /// side, and the opposite edge gets a darkened rim. That combination is
    /// what the eye reads as roundness.
    private var orb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.98), tint.opacity(0.75), tint.opacity(0.25), tint.opacity(0)],
                        center: UnitPoint(x: 0.36, y: 0.3),
                        startRadius: 2,
                        endRadius: orbDiameter * 0.78
                    )
                )
                .frame(width: orbDiameter, height: orbDiameter)
                .blur(radius: 8)

            // Shaded far edge — the shadow side of the sphere.
            Circle()
                .fill(
                    RadialGradient(colors: [.clear, .black.opacity(0.35)],
                                   center: UnitPoint(x: 0.34, y: 0.28),
                                   startRadius: orbDiameter * 0.2,
                                   endRadius: orbDiameter * 0.62)
                )
                .frame(width: orbDiameter, height: orbDiameter)
                .blendMode(.multiply)
                .blur(radius: 6)

            // Specular highlight.
            Ellipse()
                .fill(
                    RadialGradient(colors: [.white.opacity(0.75), .white.opacity(0)],
                                   center: .center, startRadius: 0, endRadius: orbDiameter * 0.22)
                )
                .frame(width: orbDiameter * 0.46, height: orbDiameter * 0.34)
                .blur(radius: 8)
                .offset(x: -orbDiameter * 0.16, y: -orbDiameter * 0.2)

            // Rim light, brightest where the shadow side begins.
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.35), .clear, tint.opacity(0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
                .frame(width: orbDiameter * 0.92, height: orbDiameter * 0.92)
                .blur(radius: 1.5)
        }
        .scaleEffect(orbScale)
        .shadow(color: tint.opacity(0.6), radius: 34)
    }

    private var label: some View {
        Text(LocalizedStringKey(trend.titleKey))
            .appFont(.footnoteSemibold)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 6)
            .transition(.opacity)
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
