//
//  ProximityHaptics.swift
//
//  A tick that speeds up as the signal strengthens — a Geiger counter for
//  headphones.
//
//  This is the one part of the radar that works without looking at the screen,
//  which matters: people search with their hands and eyes in the sofa, not on
//  the phone. It carries the same information as the dial, so nothing is lost
//  by turning it off (Settings → Feedback).
//

import Foundation
import SwiftUI
#if canImport(CoreHaptics)
import CoreHaptics
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ProximityHaptics {
    static let shared = ProximityHaptics()

    /// Gap between ticks at the weakest and strongest signal.
    private let slowestInterval: Double = 1.4
    private let fastestInterval: Double = 0.18

    private var ticker: Task<Void, Never>?
    private var isRunning = false
    private var intensity: Double = 0

    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    #endif

    private init() {}

    /// True on iPhones with the Taptic Engine. iPads and the simulator fall
    /// back to `UIImpactFeedbackGenerator`, which does nothing on hardware
    /// without haptics — silence is the correct outcome there.
    var supportsRichHaptics: Bool {
        #if canImport(CoreHaptics)
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
        #else
        return false
        #endif
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        prepareEngine()

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                self.tick()
                let interval = self.currentInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
        #if canImport(CoreHaptics)
        engine?.stop()
        #endif
    }

    /// 0 (weakest) … 1 (strongest). Drives both tick rate and tap strength.
    func update(intensity: Double) {
        self.intensity = min(max(intensity, 0), 1)
    }

    private var currentInterval: Double {
        slowestInterval - (slowestInterval - fastestInterval) * intensity
    }

    // MARK: - Engine

    private func prepareEngine() {
        #if canImport(CoreHaptics)
        guard supportsRichHaptics, engine == nil else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        // iOS stops the engine when the app backgrounds or the system needs the
        // hardware; without these the ticking stops for good after one hiccup.
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in try? self?.engine?.start() }
        }
        engine?.stoppedHandler = { _ in }
        try? engine?.start()
        #endif
    }

    private func tick() {
        #if canImport(CoreHaptics)
        if supportsRichHaptics, let engine {
            // Softer and duller when far, crisper as it closes in.
            let strength = Float(0.35 + 0.65 * intensity)
            let sharpness = Float(0.3 + 0.55 * intensity)
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: strength),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
            guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
                  let player = try? engine.makePlayer(with: pattern) else { return }
            // Cheap no-op when already running, and recovers an auto-shutdown.
            try? engine.start()
            try? player.start(atTime: 0)
            return
        }
        #endif
        fallbackTick()
    }

    private func fallbackTick() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: intensity > 0.66 ? .medium : .light)
        generator.impactOccurred(intensity: CGFloat(0.4 + 0.6 * intensity))
        #endif
    }
}
