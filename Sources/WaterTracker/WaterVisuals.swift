import SwiftUI

/// A glass orb with water sloshing inside it. Two sine waves at different
/// speeds and amplitudes read as a moving surface rather than one sliding
/// shape, a slow tilt tips the whole waterline side to side, and the level
/// tracks the day's progress. This replaces the progress ring: a hydration app
/// should look like water, not like a fitness dial.
///
/// The roundness comes from four cheap cues stacked in order — a lit interior,
/// water that darkens with depth, an elliptical surface seen slightly from
/// above, and a rim that falls into shadow away from the light.
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

    /// Light comes from the upper left; every highlight and shadow below agrees
    /// with this one point so the sphere holds together.
    private static let lightSource = UnitPoint(x: 0.33, y: 0.28)

    var body: some View {
        ZStack {
            // The dry upper half of the orb, lit from inside the glass.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Brand.ground, Brand.ground.opacity(0.7)],
                        center: Self.lightSource,
                        startRadius: 0,
                        endRadius: diameter * 0.8
                    )
                )

            if reduceMotion {
                waterShape(phase: 0)
            } else {
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    waterShape(phase: phase)
                }
            }

            // Curvature: everything away from the light falls off towards the
            // rim, water included, which is what turns the disc into a ball.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, .clear, Brand.ink.opacity(0.30)],
                        center: Self.lightSource,
                        startRadius: diameter * 0.06,
                        endRadius: diameter * 0.62
                    )
                )

            // The specular hit, where the light strikes the glass head on.
            Ellipse()
                .fill(.white.opacity(0.6))
                .frame(width: diameter * 0.3, height: diameter * 0.19)
                .rotationEffect(.degrees(-28))
                .offset(x: -diameter * 0.2, y: -diameter * 0.26)
                .blur(radius: diameter * 0.05)

            // Light wrapping the far side of the glass.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.clear, .clear, .white.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: diameter * 0.035
                )
                .blur(radius: diameter * 0.022)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .animation(.easeOut(duration: 0.7), value: progress)
    }

    private func waterShape(phase: Double) -> some View {
        Canvas { context, size in
            // A tiny sliver of water shows even at zero, so the orb never
            // looks broken, and a full day sits just above the rim.
            let level = size.height * (1 - CGFloat(min(max(progress, 0.02), 1.0)))

            // The whole body of water tips slowly, and tips harder for a moment
            // after a drink lands. This is the slosh; the waves ride on top.
            let tiltLimit = size.height * 0.035
            let tilt = reduceMotion ? 0 : sin(phase * 0.62) * tiltLimit * (1 + CGFloat(surge) * 1.5)

            for wave in waves {
                let amplitude = wave.amplitude * (1 + CGFloat(surge) * 1.8)
                var path = Path()
                var x: CGFloat = 0
                var started = false

                while x <= size.width {
                    let relative = x / size.width
                    let angle = relative * .pi * 2 * wave.frequency + phase * wave.speed * 2
                    let y = level + (relative - 0.5) * 2 * tilt + sin(angle) * amplitude
                    if started {
                        path.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        path.move(to: CGPoint(x: x, y: y))
                        started = true
                    }
                    x += 2
                }

                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()

                // Deep water is darker than the surface. Without this the fill
                // is a flat shape no matter how the top edge moves.
                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Brand.cobalt.opacity(wave.opacity),
                            Brand.cobaltDeep.opacity(wave.opacity),
                        ]),
                        startPoint: CGPoint(x: 0, y: level - size.height * 0.1),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }

            drawSurface(in: context, size: size, level: level, tilt: tilt)
            drawBubbles(in: context, size: size, level: level, phase: phase)
        }
    }

    /// The top face of the water, drawn as an ellipse because the orb is being
    /// looked at from slightly above. Its lower edge meets the front waterline,
    /// so what shows is the far half of the surface receding into the glass.
    private func drawSurface(in context: GraphicsContext, size: CGSize, level: CGFloat, tilt: CGFloat) {
        let radius = size.width / 2
        let offsetFromCentre = level - radius
        // How wide the orb is at the waterline; zero once the level clears it.
        let halfChord = sqrt(max(radius * radius - offsetFromCentre * offsetFromCentre, 0))
        guard halfChord > 4 else { return }

        let depth = min(size.height * 0.1, halfChord * 0.5)
        let rect = CGRect(
            x: radius - halfChord,
            y: level - depth + tilt * 0.15,
            width: halfChord * 2,
            height: depth * 2
        )

        context.fill(
            Path(ellipseIn: rect),
            with: .linearGradient(
                Gradient(colors: [Brand.cobaltLight.opacity(0.9), Brand.cobalt.opacity(0.55)]),
                startPoint: CGPoint(x: 0, y: rect.minY),
                endPoint: CGPoint(x: 0, y: rect.maxY)
            )
        )

        // A bright meniscus where the water climbs the glass.
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(.white.opacity(0.35)),
            lineWidth: 1.5
        )
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
                    .stroke(Brand.cobalt.opacity(0.45), lineWidth: Brand.hairline)
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
