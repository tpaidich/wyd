import SwiftUI

/// The Wyd palette: two flat colours, no gradients. Taken straight from the
/// logo, where a saturated cobalt carries a cream mark and nothing else.
enum Brand {
    static let cobalt = Color(red: 0.102, green: 0.200, blue: 0.698)   // #1A33B2
    static let cream  = Color(red: 0.973, green: 0.957, blue: 0.918)   // #F8F4EA

    /// Two steps either side of cobalt. Used only to round the progress ring's
    /// stroke into a tube; the rest of the app stays flat.
    static let cobaltLight = Color(red: 0.302, green: 0.420, blue: 0.859)   // #4D6BDB
    static let cobaltDeep  = Color(red: 0.043, green: 0.098, blue: 0.435)   // #0B1A6F

    /// Page background: cream in light, cobalt-black in dark.
    static let ground = Color("Ground")
    /// Cards and wells sit one step down from the page, in the cream family.
    /// Tinting them with cobalt instead desaturates against warm cream and
    /// comes out grey, which is what made every card read dead.
    static let surface = Color("Surface")
    /// Ink for type and rules.
    static let ink = Color("Ink")

    /// The streak keeps its warmth: it is the one thing on screen that is
    /// about momentum rather than water.
    static let flame = Color.orange

    /// Rows sit on a whisper of cobalt so they read as paper on paper,
    /// not as iOS's grey cards.
    static let rowFill = Color(red: 0.102, green: 0.200, blue: 0.698).opacity(0.05)

    /// System grey sits at roughly 3:1 on cream, which is below AA for body
    /// text. These are tinted inks instead: same hierarchy, readable contrast.
    static let inkSoft = Color("InkSoft")
    static let inkFaint = Color("InkFaint")

    static let hairline = 2.0   // the logo's line is confident, not thin

    /// One radius scale, three steps, and a rule for which to use: containers
    /// that hold other things, tiles you can tap, chips inside a tile. Pills
    /// stay capsules. Anything outside this scale is illustration, not chrome.
    static let radiusContainer: CGFloat = 22
    static let radiusTile: CGFloat = 16
    static let radiusChip: CGFloat = 10
}


extension View {
    /// Carries the Wyd theme into a Form or List: cream ground, cobalt
    /// controls, and rows on the same paper instead of system grey.
    func wydForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Brand.ground)
            .tint(Brand.ink)
    }
}


extension Image {
    /// Scales an asset to fit its frame without distortion.
    func renderable() -> some View {
        self.resizable().scaledToFit()
    }
}
