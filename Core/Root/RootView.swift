//
//  RootView.swift
//

import SwiftUI

struct RootView: View {
    @Environment(\.container) private var container
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var entitlements: Entitlements
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        TabView {
            NavigationStack(path: $router.path) {
                FinderDetectView()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .radar(let preview):
                            RadarView(isPreview: preview)
                        }
                    }
            }
            .tabItem { Label("finder.tab", systemImage: "dot.radiowaves.left.and.right") }

            SettingsView()
                .tabItem { Label("settings.tab", systemImage: "gearshape.fill") }
        }
        .tint(DS.accent)
        .fullScreenCover(isPresented: shouldShowOnboarding) {
            OnboardingView {
                withAnimation(.easeInOut(duration: DS.Motion.slow)) {
                    hasSeenOnboarding = true
                }
            }
        }
        .task {
            await entitlements.refresh()
            LeftBehindMonitor.shared.start(entitled: entitlements.hasLeftBehindAlerts,
                                           analytics: container.analytics)
        }
        .onReceive(NotificationCenter.default.publisher(for: .entitlementsDidChange)) { _ in
            // `reload`, not `refresh`: refreshing re-posts this notification.
            Task {
                await entitlements.reload()
                LeftBehindMonitor.shared.updateEntitlement(entitlements.hasLeftBehindAlerts)
            }
        }
        .onChange(of: scenePhase) { phase in
            // A subscription can lapse while the app is closed, so re-check on
            // every foreground rather than trusting the launch snapshot.
            guard phase == .active else { return }
            Task {
                await entitlements.refresh()
                LeftBehindMonitor.shared.updateEntitlement(entitlements.hasLeftBehindAlerts)
            }
        }
    }

    private var shouldShowOnboarding: Binding<Bool> {
        Binding(
            get: { container.config.featureFlags.onboarding && !hasSeenOnboarding },
            set: { hasSeenOnboarding = !$0 }
        )
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(AppRouter())
            .environmentObject(Entitlements(purchases: LocalPurchasesService(), flags: .default))
    }
}
