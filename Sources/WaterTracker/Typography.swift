import SwiftUI

/// The app is set in SF Rounded — the roundest face that ships with iOS, and
/// the one whose soft terminals match the wordmark's fat round letters.
///
/// It comes from the system rather than a font file, so unlike Helvetica it
/// carries the full weight range and scales with Dynamic Type on its own.
enum Typeface {
    static let design: Font.Design = .rounded

    /// SF Rounded is drawn with its own spacing and needs no tightening; the
    /// negative tracking Helvetica wanted closes its round counters up.
    static let tracking: CGFloat = 0
}

extension Font {
    static func app(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: Typeface.design, weight: weight)
    }

    /// `relativeTo` is kept for call-site symmetry. A system font at a fixed
    /// size does not scale itself, so every caller passes a size that has
    /// already been through `@ScaledMetric`.
    static func app(_ size: CGFloat,
                    weight: Font.Weight = .regular,
                    relativeTo style: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: weight, design: Typeface.design)
    }

    /// Kept so display sizing still lives behind one name.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        app(size, weight: weight, relativeTo: .largeTitle)
    }

    static func display(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        app(style, weight: weight)
    }
}
