//
//  TheSwiftKitApp.swift
//

import SwiftUI

@main
struct TheSwiftKitApp: App {
    private let container: DIContainer
    @StateObject private var router = AppRouter()
    @StateObject private var entitlements: Entitlements

    @AppStorage("appThemeStyle") private var themeStyleRaw: String = DS.surfaceStyle.rawValue
    @AppStorage("appearanceDark") private var appearanceDark: Bool = false
    @AppStorage("appearanceLocked") private var appearanceLocked: Bool = false

    init() {
        let container = DIContainer.makeDefault()
        self.container = container
        _entitlements = StateObject(wrappedValue: Entitlements(purchases: container.purchasesService,
                                                              flags: container.config.featureFlags))

        container.analytics.configure()
        container.analytics.track("App.Launch")
        container.purchasesService.configure()
        // Installs the notification delegate before launch completes, which is
        // what lets a left-behind alert show while the app is open.
        ReminderScheduler.shared.installDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .inject(container)
                .environmentObject(router)
                .environmentObject(entitlements)
                .dsTheme(DSTheme(surfaceStyle: SurfaceStyle(rawValue: themeStyleRaw) ?? DS.surfaceStyle))
                .preferredColorScheme(appearanceLocked ? (appearanceDark ? .dark : .light) : nil)
        }
    }
}
