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
    @State private var showRadarPaywall = false
    @State private var showAlertsPaywall = false
    @State private var didRecover = false
    @State private var scanStartedAt: Date?

    var body: some View {
        ZStack {
            AnimatedBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    statusArea
                    actionArea
                    honestyNote
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(Text("finder.title"))
        .sheet(isPresented: $showDevicePicker) {
            DevicePickerView(finder: finder)
        }
        .sheet(isPresented: $showRadarPaywall, onDismiss: handlePaywallDismiss) {
            RadarUnlockPaywallView()
        }
        .sheet(isPresented: $showAlertsPaywall) {
            LeftBehindPaywallView()
        }
        .onDisappear { finder.stopScan() }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusArea: some View {
        if didRecover {
            FinderStatusCard(systemImage: "hands.clap",
                             tint: DS.success,
                             title: "finder.recovered.title",
                             message: "finder.recovered.body",
                             isAnimating: false)
        } else {
            scanStatusArea
        }
    }

    @ViewBuilder
    private var scanStatusArea: some View {
        switch finder.state {
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
        if didRecover {
            Button(action: startScan) {
                Label("finder.scan.again", systemImage: "magnifyingglass")
            }
            .buttonStyle(DSSecondaryButtonStyle())
        } else {
            scanActionArea
        }
    }

    @ViewBuilder
    private var scanActionArea: some View {
        VStack(spacing: DS.Spacing.md) {
            switch finder.state {
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

    private var honestyNote: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(DS.Colors.textSecondary)
            Text("finder.honest.note")
                .appFont(.footnote)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.md)
        .dsCard(radius: DS.Radius.md)
    }

    // MARK: - Intent

    private func startScan() {
        didRecover = false
        scanStartedAt = Date()
        container.analytics.track(AnalyticsEvent.scanStarted)
        finder.startScan()
    }

    private func openRadar() {
        if entitlements.isRadarUnlocked {
            router.push(.radar)
        } else {
            showRadarPaywall = true
        }
    }

    private func handlePaywallDismiss() {
        if entitlements.isRadarUnlocked { router.push(.radar) }
    }

    private func confirmRecovered() {
        var properties: [String: String] = [AnalyticsProperty.source: "detect"]
        if let scanStartedAt {
            properties[AnalyticsProperty.durationSeconds] = String(Int(Date().timeIntervalSince(scanStartedAt)))
        }
        container.analytics.track(AnalyticsEvent.findSucceeded, properties: properties)
        finder.stopScan()
        didRecover = true

        // One ask per find: the subscription offer, or the review prompt.
        let offersAlerts = container.config.featureFlags.leftBehindAlerts
            && LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: entitlements.hasLeftBehindAlerts)
        if offersAlerts {
            showAlertsPaywall = true
        } else if container.config.featureFlags.reviewPrompt {
            ReviewManager.shared.registerSignificantEvent()
        }
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
                if isAnimating {
                    Circle()
                        .stroke(tint.opacity(0.35), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulse ? 1.25 : 0.85)
                        .opacity(pulse ? 0 : 1)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
                }
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 104, height: 104)
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(tint)
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

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle().fill(DS.success.opacity(0.15)).frame(width: 104, height: 104)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(DS.success)
            }
            .frame(height: 130)

            VStack(spacing: DS.Spacing.sm) {
                Text("finder.found.title").appFont(.title3)
                Text(device.name.isEmpty ? String(localized: "finder.device.unknown") : device.name)
                    .appFont(.headline)
                    .foregroundStyle(DS.accent)
                Text("finder.found.body")
                    .appFont(.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
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
