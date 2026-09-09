import SwiftUI

/// One typeface for the whole app: SF Pro, the iOS system font.
///
/// These helpers stay in place so display sizing lives in one file, but they
/// no longer switch design. Everything renders in SF Pro.
extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    static func display(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style).weight(weight)
    }
}
