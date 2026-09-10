import SwiftUI

/// The moment before the app appears. A droplet falls, lands, and the ripple
/// it leaves becomes the water the app is about. Short on purpose: this plays
/// once at launch and must never feel like a delay.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dropY: CGFloat = -180
    @State private var dropScale: CGFloat = 1
    @State private var dropOpacity: Double = 1
    @State private var ripple: CGFloat = 0.1
    @State private var rippleOpacity: Double = 0
    @State private var fillProgress: Double = 0
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            Brand.cobalt.ignoresSafeArea()

            VStack(spacing: 26) {
                ZStack {
                    // The water the droplet lands in.
                    WaveFillCircle(progress: fillProgress, diameter: 132)
                        .opacity(fillProgress > 0 ? 1 : 0)

                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.cyan.opacity(0.45), lineWidth: 2)
                            .frame(width: 132, height: 132)
                            .scaleEffect(ripple + CGFloat(index) * 0.22)
                            .opacity(rippleOpacity)
                    }

                    Image(systemName: "drop.fill")
                        .font(.app(42, relativeTo: .largeTitle))
                        .foregroundStyle(Brand.cream)
                        .scaleEffect(x: 1 / max(dropScale, 0.6), y: dropScale)
                        .offset(y: dropY)
                        .opacity(dropOpacity)
                }
                .frame(width: 150, height: 150)

                VStack(spacing: 4) {
                    Text("wyd")
                        .font(.app(62, weight: .black, relativeTo: .largeTitle))
                        .foregroundStyle(Brand.cream)
                    Text("What're You Drinking?")
                        .font(.app(16, weight: .medium, relativeTo: .largeTitle))
                        .foregroundStyle(Brand.cream.opacity(0.85))
                }
                .opacity(titleOpacity)
            }
        }
        .onAppear(perform: play)
    }

    /// The droplet has touched the surface: it sinks in, the rings spread, and
    /// the water rises behind them.
    private func land() {
        withAnimation(.easeOut(duration: 0.18)) {
            dropOpacity = 0
            dropScale = 0.7
        }

        ripple = 0.1
        rippleOpacity = 0.9
        withAnimation(.easeOut(duration: 0.9)) {
            ripple = 1.3
            rippleOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.85)) {
            fillProgress = 0.55
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
            titleOpacity = 1
        } completion: {
            onFinish()
        }
    }

    private func play() {
        guard !reduceMotion else {
            fillProgress = 0.55
            titleOpacity = 1
            dropOpacity = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onFinish() }
            return
        }

        // Fall, with a slight stretch as it accelerates. The splash chains off
        // the animation's own completion rather than a wall-clock delay, so a
        // slow first frame on cold launch cannot let the ripple outrun the drop.
        withAnimation(.easeIn(duration: 0.42)) {
            dropY = 0
            dropScale = 1.25
        } completion: {
            land()
        }
    }
}
