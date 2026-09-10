import SwiftUI

/// The Wyd palette: two flat colours, no gradients. Taken straight from the
/// logo, where a saturated cobalt carries a cream mark and nothing else.
enum Brand {
    static let cobalt = Color(red: 0.102, green: 0.200, blue: 0.698)   // #1A33B2
    static let cream  = Color(red: 0.973, green: 0.957, blue: 0.918)   // #F8F4EA

    /// Page background: cream in light, cobalt-black in dark.
    static let ground = Color("Ground")
    /// Ink for type and rules.
    static let ink = Color("Ink")

    /// The streak keeps its warmth: it is the one thing on screen that is
    /// about momentum rather than water.
    static let flame = Color.orange

    /// Rows sit on a whisper of cobalt so they read as paper on paper,
    /// not as iOS's grey cards.
    static let rowFill = Color(red: 0.102, green: 0.200, blue: 0.698).opacity(0.05)

    static let hairline = 2.0   // the logo's line is confident, not thin
    static let radius = 18.0
}


extension View {
    /// Carries the Wyd theme into a Form or List: cream ground, cobalt
    /// controls, and rows on the same paper instead of system grey.
    func wydForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Brand.ground)
            .listRowBackground(Brand.rowFill)
            .tint(Brand.ink)
    }
}


extension Image {
    /// Scales an asset to fit its frame without distortion.
    func renderable() -> some View {
        self.resizable().scaledToFit()
    }
}
