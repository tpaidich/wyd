import SwiftUI

/// A glass of water that actually fills. Two sine waves at different speeds
/// and amplitudes read as a moving surface rather than one sliding shape, and
/// the level tracks the day's progress. This replaces the progress ring: a
/// hydration app should look like water, not like a fitness dial.
struct WaveFillCircle: View {
    var progress: Double
    var diameter: CGFloat
    /// Rises briefly after a drink is logged, so the surface reacts instead of
    /// silently sliding to a new level.
    var surge: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fixed seeds, so bubbles drift consistently rather than jumping around
    /// every time SwiftUI rebuilds the view.
    private static let bubbles: [(x: CGFloat, size: CGFloat, speed: Double, phase: Double)] = [
        (0.22, 4.5, 0.34, 0.0), (0.38, 3.0, 0.52, 1.7), (0.52, 5.5, 0.27, 0.6),
        (0.66, 3.5, 0.44, 2.4), (0.78, 4.0, 0.38, 1.1), (0.30, 2.5, 0.61, 3.0),
        (0.58, 2.8, 0.55, 2.0), (0.44, 4.2, 0.31, 3.6),
    ]

    private struct Wave {
        let amplitude: CGFloat
        let frequency: CGFloat
        let speed: Double
        let opacity: Double
    }

    private let waves = [
        Wave(amplitude: 7, frequency: 1.0, speed: 0.55, opacity: 0.32),
        Wave(amplitude: 5, frequency: 1.6, speed: -0.85, opacity: 0.85),
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.08))

            if reduceMotion {
                waterShape(phase: 0)
            } else {
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    waterShape(phase: phase)
                }
            }

            Circle()
                .strokeBorder(Color.blue.opacity(0.16), lineWidth: 2)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .animation(.easeOut(duration: 0.7), value: progress)
    }

    private func waterShape(phase: Double) -> some View {
        Canvas { context, size in
            // A tiny sliver of water shows even at zero, so the glass never
            // looks broken, and a full day sits just above the rim.
            let level = size.height * (1 - CGFloat(min(max(progress, 0.02), 1.0)))

            for wave in waves {
                let amplitude = wave.amplitude * (1 + CGFloat(surge) * 1.8)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: level))

                var x: CGFloat = 0
                while x <= size.width {
                    let relative = x / size.width
                    let angle = relative * .pi * 2 * wave.frequency + phase * wave.speed * 2
                    let y = level + sin(angle) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 2
                }

                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.cyan.opacity(wave.opacity),
                            Color.blue.opacity(wave.opacity),
                        ]),
                        startPoint: CGPoint(x: 0, y: level),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }

            drawBubbles(in: context, size: size, level: level, phase: phase)
        }
    }

    /// Bubbles rise from the base and fade as they near the surface, which is
    /// what makes the fill read as liquid rather than a coloured shape.
    private func drawBubbles(in context: GraphicsContext, size: CGSize, level: CGFloat, phase: Double) {
        guard !reduceMotion, progress > 0.05 else { return }

        let depth = size.height - level
        guard depth > 12 else { return }

        for bubble in Self.bubbles {
            let travel = (phase * bubble.speed + bubble.phase).truncatingRemainder(dividingBy: 1)
            let y = size.height - CGFloat(travel) * depth
            guard y > level else { continue }

            // Drift sideways a little as they climb, and fade near the surface.
            let sway = sin(travel * .pi * 3 + bubble.phase) * 5
            let x = size.width * bubble.x + CGFloat(sway)
            let fade = min(1, (y - level) / max(depth * 0.35, 1))

            let rect = CGRect(
                x: x - bubble.size / 2,
                y: y - bubble.size / 2,
                width: bubble.size,
                height: bubble.size
            )
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.42 * Double(fade))))
        }
    }

}

/// Rings that spread from the centre when a drink lands, so logging feels like
/// something hit the water.
struct RippleOverlay: View {
    var trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                    .scaleEffect(scale + CGFloat(index) * 0.18)
                    .opacity(opacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            scale = 0.2
            opacity = 0.9
            withAnimation(.easeOut(duration: 0.85)) {
                scale = 1.25
                opacity = 0
            }
        }
    }
}
