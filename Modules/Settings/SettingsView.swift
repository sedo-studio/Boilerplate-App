//
//  SettingsView.swift
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.container) private var container
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var entitlements: Entitlements
    @StateObject private var monitor = LeftBehindMonitor.shared
    @StateObject private var finder = BluetoothFinder.shared
    @StateObject private var scheduler = ReminderScheduler.shared

    @AppStorage("appearanceDark") private var appearanceDark: Bool = false
    @AppStorage("appearanceLocked") private var appearanceLocked: Bool = false

    @State private var showRadarPaywall = false
    @State private var showAlertsPaywall = false
    @State private var showForgetConfirmation = false
    @State private var message: String?

    private var flags: FeatureFlags { container.config.featureFlags }

    var body: some View {
        NavigationStack {
            List {
                headphonesSection
                if flags.radarUnlock { radarSection }
                if flags.leftBehindAlerts { alertsSection }
                purchasesSection
                appearanceSection
                aboutSection
            }
            .navigationTitle(Text("settings.title"))
            .sheet(isPresented: $showRadarPaywall) { RadarUnlockPaywallView() }
            .sheet(isPresented: $showAlertsPaywall) { LeftBehindPaywallView() }
            .task { await scheduler.refresh() }
            .alert(Text("settings.alert.title"), isPresented: .constant(message != nil)) {
                Button("generic.ok") { message = nil }
            } message: {
                Text(message ?? "")
            }
            .confirmationDialog(Text("settings.device.forget.confirm"),
                                isPresented: $showForgetConfirmation,
                                titleVisibility: .visible) {
                Button("settings.device.forget", role: .destructive) { finder.forgetDevice() }
                Button("generic.cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Sections

    private var headphonesSection: some View {
        Section("settings.device.section") {
            if let name = finder.savedDeviceName {
                HStack {
                    Label(name, systemImage: "airpodspro")
                    Spacer()
                }
                Button(role: .destructive) { showForgetConfirmation = true } label: {
                    Label("settings.device.forget", systemImage: "trash")
                }
            } else {
                Text("settings.device.none")
                    .appFont(.footnote)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
    }

    private var radarSection: some View {
        Section {
            if entitlements.isRadarUnlocked {
                Label("settings.radar.unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(DS.success)
            } else {
                Button { showRadarPaywall = true } label: {
                    Label("settings.radar.unlock", systemImage: "dot.radiowaves.forward")
                }
            }
        } header: {
            Text("settings.radar.section")
        } footer: {
            Text("settings.radar.footer")
        }
    }

    private var alertsSection: some View {
        Section {
            if entitlements.hasLeftBehindAlerts {
                Toggle(isOn: alertsToggleBinding) {
                    Label("settings.alerts.toggle", systemImage: "bell.badge")
                }
                if monitor.isEnabled && !scheduler.isAuthorized {
                    Button { scheduler.openSystemSettings() } label: {
                        Label("settings.alerts.permission", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(DS.warning)
                    }
                }
                Button {
                    Task { await entitlements.showManageSubscriptions() }
                } label: {
                    Label("settings.alerts.manage", systemImage: "creditcard")
                }
            } else {
                Button { showAlertsPaywall = true } label: {
                    Label("settings.alerts.subscribe", systemImage: "bell.badge")
                }
            }
        } header: {
            Text("settings.alerts.section")
        } footer: {
            Text(entitlements.hasLeftBehindAlerts ? "settings.alerts.footer.on" : "settings.alerts.footer.off")
        }
    }

    private var purchasesSection: some View {
        Section("settings.purchases.section") {
            Button {
                Task {
                    do {
                        try await entitlements.restore()
                        message = String(localized: "settings.restore.done")
                    } catch {
                        message = error.localizedDescription
                    }
                }
            } label: {
                Label("settings.restore", systemImage: "arrow.clockwise")
            }
        }
    }

    private var appearanceSection: some View {
        Section("settings.appearance") {
            Toggle(isOn: Binding(
                get: { appearanceLocked ? appearanceDark : (scheme == .dark) },
                set: { newValue in
                    appearanceDark = newValue
                    appearanceLocked = true
                }
            )) {
                Label("settings.darkmode", systemImage: "moon.fill")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            if flags.reviewPrompt {
                Button { ReviewManager.shared.requestNativeReviewNow() } label: {
                    Label("settings.rate", systemImage: "star")
                }
            }
            Link(destination: container.config.legal.privacyPolicyURL) {
                Label("settings.privacy", systemImage: "hand.raised")
            }
            Link(destination: container.config.legal.termsURL) {
                Label("settings.terms", systemImage: "doc.text")
            }
        } header: {
            Text("settings.about.section")
        } footer: {
            Text("settings.about.footer")
        }
    }

    // MARK: - Intent

    private var alertsToggleBinding: Binding<Bool> {
        Binding(
            get: { monitor.isEnabled },
            set: { newValue in
                guard newValue else {
                    monitor.disable()
                    return
                }
                Task {
                    let granted = await monitor.enable()
                    if !granted {
                        message = String(localized: "settings.alerts.permission.denied")
                    }
                }
            }
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(Entitlements(purchases: LocalPurchasesService(), flags: .default))
    }
}
