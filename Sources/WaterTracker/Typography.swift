import SwiftUI

/// The app is set in Helvetica Neue, tracked slightly tight.
///
/// Helvetica Neue ships six upright weights — UltraLight, Thin, Light,
/// Regular, Medium and Bold — so medium now has a face of its own instead of
/// collapsing to regular. There is no semibold or black, so those round up to
/// bold. Sizes mirror what iOS uses for each text style and are declared
/// `relativeTo`, so Dynamic Type still scales the whole interface.
enum Typeface {
    static func helvetica(_ weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight:
            return "HelveticaNeue-UltraLight"
        case .thin:
            return "HelveticaNeue-Thin"
        case .light:
            return "HelveticaNeue-Light"
        case .medium:
            return "HelveticaNeue-Medium"
        case .semibold, .bold, .heavy, .black:
            return "HelveticaNeue-Bold"
        default:
            return "HelveticaNeue"
        }
    }

    static func size(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}

extension Font {
    static func app(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom(Typeface.helvetica(weight),
                size: Typeface.size(for: style),
                relativeTo: style)
    }

    static func app(_ size: CGFloat,
                    weight: Font.Weight = .regular,
                    relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(Typeface.helvetica(weight), size: size, relativeTo: style)
    }

    /// Kept so display sizing still lives behind one name.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        app(size, weight: weight, relativeTo: .largeTitle)
    }

    static func display(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        app(style, weight: weight)
    }
}
