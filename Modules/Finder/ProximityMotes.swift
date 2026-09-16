//
//  ProximityMotes.swift
//
//  Drifting points of light around the dial. They travel inward while the
//  signal is strengthening and outward while it fades, which puts the trend
//  into motion instead of leaving it to the label alone.
//
//  They converge on the centre of the dial from every angle at once — never
//  from one side. A stream arriving from a single direction would read as
//  "they're over there", which is the one thing this app must not imply.
//
//  Positions are computed from the clock rather than stepped, so there is no
//  particle state to keep in sync and nothing to drift out of phase.
//

import SwiftUI

struct ProximityMotes: View {
    /// 0 (weakest) … 1 (strongest).
    let intensity: Double
    let trend: ProximityTrend
    let tint: Color

    private let count = 22
    /// Golden angle: spreads the motes evenly without them forming spokes.
    private let goldenAngle = 2.399963

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) / 2
                context.addFilter(.blur(radius: 2.5))

                for index in 0..<count {
                    let seed = Double(index)
                    let phase = seed / Double(count)
                    let jitter = (seed * 0.37).truncatingRemainder(dividingBy: 1)
                    let speed = 0.14 + 0.1 * jitter + 0.16 * intensity
                    let progress = (time * speed + phase).truncatingRemainder(dividingBy: 1)

                    let radial: Double
                    let fade: Double
                    switch trend {
                    case .warmer:
                        radial = 1 - progress                       // edge → centre
                        fade = sin(.pi * progress)
                    case .colder:
                        radial = progress                           // centre → edge
                        fade = sin(.pi * progress)
                    case .steady:
                        radial = 0.55 + 0.1 * sin(time * 0.5 + seed)  // gentle hover
                        fade = 0.75
                    }

                    // Slow rotation keeps it alive when the radius is static.
                    let angle = seed * goldenAngle + time * 0.06
                    let distance = maxRadius * (0.16 + 0.84 * radial)
                    let point = CGPoint(x: center.x + cos(angle) * distance,
                                        y: center.y + sin(angle) * distance)

                    let alpha = fade * (0.2 + 0.45 * intensity)
                    let dot = 1.8 + 2.4 * intensity * fade
                    let rect = CGRect(x: point.x - dot / 2, y: point.y - dot / 2,
                                      width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
