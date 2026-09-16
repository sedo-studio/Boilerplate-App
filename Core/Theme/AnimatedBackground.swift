//
//  AnimatedBackground.swift
//
//  Deep, slowly drifting glow behind every screen. Kept low-contrast on
//  purpose — it should read as atmosphere, never as content.
//

import SwiftUI

struct AnimatedBackground: View {
    /// Brightness of the drifting blobs. The radar turns this down so its own
    /// glow is the only strong light on screen.
    var intensity: Double = 1.0

    var body: some View {
        ZStack {
            DS.Colors.background

            TimelineView(.animation) { context in
                Canvas { ctx, size in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let colors = [DS.primary, DS.accent, DS.cold]
                    for i in 0..<5 {
                        // Slower than a lava lamp: a full loop takes ~75s.
                        let phase = t / 12 + Double(i) * 0.5
                        let x = cos(phase) * (size.width * 0.3) + size.width * [0.25, 0.8, 0.5, 0.7, 0.3][i]
                        let y = sin(phase * 0.8) * (size.height * 0.22) + size.height * [0.18, 0.32, 0.72, 0.5, 0.85][i]
                        let radius: CGFloat = 190
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        ctx.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [colors[i % colors.count].opacity(0.22 * intensity), .clear]),
                                center: CGPoint(x: rect.midX, y: rect.midY),
                                startRadius: 0,
                                endRadius: radius
                            )
                        )
                    }
                }
            }
            .blur(radius: 30)

            // Sinks the bottom of the screen so bottom-anchored buttons keep
            // their contrast wherever the blobs happen to drift.
            LinearGradient(
                colors: [.clear, DS.Colors.background.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
