//
//  FinderDetectView.swift
//
//  The free screen: scan, and confirm the headphones are in range. No distance,
//  no direction — that is the paid radar. This screen's job is to prove the app
//  works before asking for money.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FinderDetectView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var entitlements: Entitlements
    @StateObject private var finder = BluetoothFinder.shared

    @State private var showDevicePicker = false
    @State private var showAlertsPaywall = false
    @State private var scanStartedAt: Date?

    var body: some View {
        ZStack {
            AnimatedBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    statusArea
                    actionArea
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(Text("finder.title"))
        .sheet(isPresented: $showDevicePicker) {
            DevicePickerView(finder: finder)
        }
        .sheet(isPresented: $showAlertsPaywall) {
            LeftBehindPaywallView()
        }
        .onChange(of: finder.state) { newState in
            // On the transition, not on appear — coming back from the radar
            // shouldn't buzz again.
            if case .found = newState { playFoundHaptic() }
            // The radar hands the hunt back here when it ends, so the wrap-up
            // runs in one place wherever the user tapped "I've got them".
            if case .recovered = newState {
                FindWrapUp.perform(container: container, entitlements: entitlements) {
                    showAlertsPaywall = true
                }
            }
        }
        .onDisappear { finder.stopScan() }
    }

    private func playFoundHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    // MARK: - Status

    @ViewBuilder
    private var statusArea: some View {
        switch finder.state {
        case .recovered:
            FinderStatusCard(systemImage: "hands.clap",
                             tint: DS.success,
                             title: "finder.recovered.title",
                             message: "finder.recovered.body",
                             isAnimating: false)
        case .idle:
            FinderStatusCard(systemImage: "airpodspro",
                             tint: DS.accent,
                             title: "finder.idle.title",
                             message: "finder.idle.body",
                             isAnimating: false)
        case .scanning:
            FinderStatusCard(systemImage: "dot.radiowaves.left.and.right",
                             tint: DS.accent,
                             title: "finder.scanning.title",
                             message: "finder.scanning.body",
                             isAnimating: true)
        case .found(let device):
            FoundCard(device: device)
        case .notFound:
            FinderStatusCard(systemImage: "questionmark.circle",
                             tint: DS.warning,
                             title: "finder.notfound.title",
                             message: "finder.notfound.body",
                             isAnimating: false)
            TroubleshootingCard()
        case .unauthorized:
            FinderStatusCard(systemImage: "lock.slash",
                             tint: DS.danger,
                             title: "finder.bluetooth.denied.title",
                             message: "finder.bluetooth.denied.body",
                             isAnimating: false)
        case .poweredOff:
            FinderStatusCard(systemImage: "bolt.horizontal.circle",
                             tint: DS.warning,
                             title: "finder.bluetooth.off.title",
                             message: "finder.bluetooth.off.body",
                             isAnimating: false)
        case .unsupported:
            FinderStatusCard(systemImage: "exclamationmark.triangle",
                             tint: DS.danger,
                             title: "finder.unsupported.title",
                             message: "finder.unsupported.body",
                             isAnimating: false)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionArea: some View {
        VStack(spacing: DS.Spacing.md) {
            switch finder.state {
            case .recovered:
                Button(action: startScan) {
                    Label("finder.scan.again", systemImage: "magnifyingglass")
                }
                .buttonStyle(DSSecondaryButtonStyle())

            case .idle, .notFound:
                Button(action: startScan) {
                    Label("finder.scan.cta", systemImage: "magnifyingglass")
                }
                .buttonStyle(DSPrimaryButtonStyle())

            case .scanning:
                Button("finder.scan.stop") { finder.stopScan() }
                    .buttonStyle(DSSecondaryButtonStyle())

            case .found:
                Button(action: openRadar) {
                    Label("finder.found.cta", systemImage: "dot.radiowaves.forward")
                }
                .buttonStyle(DSPrimaryButtonStyle())

                Button("finder.found.gotthem") { confirmRecovered() }
                    .buttonStyle(DSSecondaryButtonStyle())

            case .unauthorized, .poweredOff:
                Button("finder.opensettings") { openSystemSettings() }
                    .buttonStyle(DSPrimaryButtonStyle())

            case .unsupported:
                EmptyView()
            }

            if !finder.candidates.isEmpty {
                Button("finder.picker.cta") { showDevicePicker = true }
                    .buttonStyle(DSGhostButtonStyle())
            }
        }
    }

    // MARK: - Intent

    private func startScan() {
        scanStartedAt = Date()
        container.analytics.track(AnalyticsEvent.scanStarted)
        finder.startScan()
    }

    /// Locked users get the real radar for a few seconds before the paywall —
    /// the feature argues for itself better than a screenshot of it does.
    private func openRadar() {
        router.push(.radar(preview: !entitlements.isRadarUnlocked))
    }

    private func confirmRecovered() {
        var properties: [String: String] = [AnalyticsProperty.source: "detect"]
        if let scanStartedAt {
            properties[AnalyticsProperty.durationSeconds] = String(Int(Date().timeIntervalSince(scanStartedAt)))
        }
        container.analytics.track(AnalyticsEvent.findSucceeded, properties: properties)
        finder.markRecovered()   // the state change runs the wrap-up above
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Status card

private struct FinderStatusCard: View {
    let systemImage: String
    let tint: Color
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let isAnimating: Bool

    @State private var pulse = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                // Soft bloom, same visual language as the radar.
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.45), tint.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 90))
                    .frame(width: 180, height: 180)
                    .blur(radius: 24)

                if isAnimating {
                    Circle()
                        .stroke(tint.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 140, height: 140)
                        .blur(radius: 2)
                        .scaleEffect(pulse ? 1.3 : 0.8)
                        .opacity(pulse ? 0 : 1)
                        .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: pulse)
                }

                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 104, height: 104)

                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.6), radius: 14)
            }
            .frame(height: 150)

            VStack(spacing: DS.Spacing.sm) {
                Text(title).appFont(.title3).multilineTextAlignment(.center)
                Text(message)
                    .appFont(.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .dsCard(radius: DS.Radius.lg)
        .onAppear { if isAnimating { pulse = true } }
    }
}

// MARK: - Found card

private struct FoundCard: View {
    let device: DiscoveredDevice

    /// Three layers, all on different clocks: a slow breathing halo, a ring
    /// that sweeps outward every couple of seconds, and a one-off spring as
    /// the mark lands. Staggering them is what keeps it from looking like a
    /// loading spinner.
    @State private var landed = false
    @State private var breathing = false
    @State private var sweeping = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [DS.success.opacity(0.45), DS.success.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 90))
                    .frame(width: 180, height: 180)
                    .blur(radius: 24)
                    .scaleEffect(breathing ? 1.08 : 0.9)
                    .opacity(breathing ? 0.85 : 0.5)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: breathing)

                Circle()
                    .strokeBorder(DS.success.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 112, height: 112)
                    .blur(radius: 1.5)
                    .scaleEffect(sweeping ? 1.7 : 0.95)
                    .opacity(sweeping ? 0 : 0.85)
                    .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false), value: sweeping)

                Circle()
                    .fill(DS.success.opacity(0.15))
                    .frame(width: 104, height: 104)
                    .scaleEffect(landed ? 1 : 0.75)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(DS.success)
                    .shadow(color: DS.success.opacity(0.6), radius: 14)
                    .scaleEffect(landed ? 1 : 0.5)
                    .opacity(landed ? 1 : 0)
            }
            .frame(height: 130)
            .onAppear {
                withAnimation(DS.Motion.spring) { landed = true }
                breathing = true
                sweeping = true
            }

            VStack(spacing: DS.Spacing.sm) {
                Text("finder.found.title").appFont(.title3)
                Text(device.name.isEmpty ? String(localized: "finder.device.unknown") : device.name)
                    .appFont(.headline)
                    .foregroundStyle(DS.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .dsCard(radius: DS.Radius.lg)
    }
}

// MARK: - Troubleshooting

private struct TroubleshootingCard: View {
    private let tips: [LocalizedStringKey] = [
        "finder.notfound.tip1",
        "finder.notfound.tip2",
        "finder.notfound.tip3"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("finder.notfound.tips.title").appFont(.headline)
            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.top, 7)
                    Text(tip).appFont(.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .dsCard(radius: DS.Radius.lg)
    }
}

// MARK: - Device picker

private struct DevicePickerView: View {
    @ObservedObject var finder: BluetoothFinder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if finder.allNamedCandidates.isEmpty {
                        Text("finder.picker.empty")
                            .appFont(.footnote)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    ForEach(finder.allNamedCandidates) { device in
                        Button {
                            finder.select(device)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name).appFont(.body)
                                    if device.isConnected {
                                        Text("finder.picker.connected")
                                            .appFont(.caption)
                                            .foregroundStyle(DS.success)
                                    }
                                }
                                Spacer()
                                if device.id == finder.trackedDevice?.id {
                                    Image(systemName: "checkmark").foregroundStyle(DS.accent)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("finder.picker.footer")
                }
            }
            .navigationTitle(Text("finder.picker.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("generic.done") { dismiss() }
                }
            }
        }
    }
}

struct FinderDetectView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { FinderDetectView() }
            .environmentObject(AppRouter())
            .environmentObject(Entitlements(purchases: LocalPurchasesService(), flags: .default))
    }
}
