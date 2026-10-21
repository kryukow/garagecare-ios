import SwiftUI

/// Shared visual tokens for GarageCare.
///
/// Keep screen code expressed in semantic roles rather than one-off values.
/// The values mirror replica/design/tokens.json.
enum GarageTokens {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let hero: CGFloat = 26
        static let pill: CGFloat = 999
    }

    enum Size {
        static let minimumTouchTarget: CGFloat = 44
        static let progressBarHeight: CGFloat = 2
        static let statusDot: CGFloat = 7
    }

    enum Motion {
        static let quick: Double = 0.18
        static let standard: Double = 0.28
    }

    enum Shadow {
        static let cardColor = Color.black.opacity(0.22)
        static let cardRadius: CGFloat = 16
        static let cardY: CGFloat = 8

        static let floatingColor = Color.black.opacity(0.30)
        static let floatingRadius: CGFloat = 20
        static let floatingY: CGFloat = 10
    }

    enum Opacity {
        static let subtleFill: Double = 0.08
        static let accentFill: Double = 0.12
        static let subtleStroke: Double = 0.20
        static let backgroundAccent: Double = 0.08
    }
}
