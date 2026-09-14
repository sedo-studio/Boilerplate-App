//
//  AppLockGate.swift
//
//  Applies the biometric lock overlay at the app root. Apply once, in
//  `TheSwiftKitApp.swift`, via `.appLockGate(enabled:)`.
//

import SwiftUI

struct AppLockGate: ViewModifier {
    let enabled: Bool
    @StateObject private var lock = AppLockManager.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        ZStack {
            content
            if enabled && lock.isLocked {
                AppLockScreen { lock.authenticate() }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: DS.Motion.normal), value: lock.isLocked)
        .onAppear {
            guard enabled else { return }
            lock.lockIfEnabled()
            if lock.isLocked { lock.authenticate() }
        }
        .onChange(of: scenePhase) { newPhase in
            guard enabled else { return }
            switch newPhase {
            case .active:
                if lock.isLocked { lock.authenticate() }
            case .background:
                lock.lockIfEnabled()
            default:
                break
            }
        }
    }
}

extension View {
    /// Gate the app behind a biometric lock when the feature is enabled and the
    /// user has opted in. No-ops entirely when `enabled` is false.
    func appLockGate(enabled: Bool) -> some View {
        modifier(AppLockGate(enabled: enabled))
    }
}

/// Full-screen cover shown while the app is locked.
struct AppLockScreen: View {
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(DS.accent)
                Text("applock.title")
                    .appFont(.title2)
                Text("applock.subtitle")
                    .appFont(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    onUnlock()
                } label: {
                    Label("applock.unlock", systemImage: "faceid")
                        .padding(.horizontal, DS.Spacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
            }
            .padding(DS.Spacing.xl)
        }
    }
}
