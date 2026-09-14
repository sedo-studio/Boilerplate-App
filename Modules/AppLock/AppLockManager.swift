//
//  AppLockManager.swift
//
//  PRO feature — biometric (Face ID / Touch ID) app lock.
//  Self-contained: delete the `Modules/AppLock` folder, remove the
//  `.appLockGate(...)` line in `TheSwiftKitApp.swift` and the lock toggle in
//  `SettingsView.swift`, and flip `featureFlags.biometricLock` off to remove it.
//
//  The feature flag only makes the lock *available*. The user opts in via the
//  Settings toggle (persisted as `appLockEnabled`); until then nothing locks.
//

import Foundation
import SwiftUI
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    /// `true` while the lock screen should be covering the app.
    @Published private(set) var isLocked = false

    private var isAuthenticating = false
    private let enabledKey = "appLockEnabled"

    /// User opt-in, persisted across launches. Bound by the Settings toggle.
    var isEnabledByUser: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Whether the device can authenticate, plus a human label for the UI.
    func availability() -> (available: Bool, label: String) {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return (false, "Unavailable")
        }
        switch ctx.biometryType {
        case .faceID:  return (true, "Face ID")
        case .touchID: return (true, "Touch ID")
        default:       return (true, "Passcode")
        }
    }

    func lockIfEnabled() {
        if isEnabledByUser { isLocked = true }
    }

    /// Force the lock immediately (used by the demo's "Lock Now" button).
    func lockNow() {
        isLocked = true
    }

    /// Present the system biometric/passcode prompt and unlock on success.
    /// If the device can't authenticate at all, we unlock rather than trapping
    /// the user out of their own app.
    func authenticate() {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true

        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isAuthenticating = false
            isLocked = false
            return
        }

        let reason = NSLocalizedString("applock.reason", comment: "")
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            Task { @MainActor in
                self.isAuthenticating = false
                if success { self.isLocked = false }
            }
        }
    }

    /// Standalone biometric check for the demo hub — prompts Face ID / Touch ID
    /// (or device passcode) and reports the outcome, independent of lock state.
    func runBiometricTest(completion: @escaping (String) -> Void) {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let detail = error?.localizedDescription ?? "no biometrics or passcode enrolled"
            completion("Unavailable — \(detail)\n\nOn the Simulator: Features ▸ Face ID ▸ Enrolled, then run again.")
            return
        }
        let (_, label) = availability()
        let reason = NSLocalizedString("applock.reason", comment: "")
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, err in
            Task { @MainActor in
                if success {
                    completion("\(label) authentication succeeded ✅")
                } else {
                    completion("\(label) authentication failed or cancelled.\n\(err?.localizedDescription ?? "")")
                }
            }
        }
    }
}
