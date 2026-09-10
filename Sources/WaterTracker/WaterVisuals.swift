import SwiftUI

/// Rings that spread from the centre when something is logged, so a tap has a
/// visible consequence even when the level barely moves.
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
