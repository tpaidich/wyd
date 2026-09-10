import SwiftUI

/// The moment before the app appears: the cover art, and nothing else.
///
/// The ground is the artwork's own blue rather than `Brand.cobalt`, so the
/// image has no edge against the screen and the logo reads as if it were
/// printed on it. Short on purpose — this plays once at launch and must never
/// feel like a delay.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scale: CGFloat = 0.88
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()

            Image("LaunchLogo")
                .renderable()
                .frame(maxWidth: 300)
                .scaleEffect(scale)
                .opacity(opacity)
                .accessibilityLabel("Wyd, what're you drinking")
        }
        .onAppear(perform: play)
    }

    private func play() {
        guard !reduceMotion else {
            scale = 1
            opacity = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onFinish() }
            return
        }

        // Settle, hold for a beat, then hand over. Chaining off the animation's
        // own completion rather than a wall-clock delay keeps a slow first frame
        // on cold launch from cutting the logo short.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            scale = 1
            opacity = 1
        } completion: {
            withAnimation(.easeOut(duration: 0.2).delay(0.35)) {
                scale = 1.04
            } completion: {
                onFinish()
            }
        }
    }
}
