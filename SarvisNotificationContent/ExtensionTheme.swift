import SwiftUI

/// Duplicate of the host app's Theme tokens needed by the Notification Content Extension.
/// Extensions cannot import the host app's module across target boundaries, so we
/// keep a minimal copy here. Keep in sync with Sarvis/UI/Theme.swift when tokens change.
enum ExtensionTheme {

    // MARK: Spacing scale (4-pt base, 8-pt rhythm)
    enum Spacing {
        static let hair: CGFloat = 2
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 32
    }

    // MARK: Corner radii
    enum Radius {
        static let chip: CGFloat = 12
        static let card: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: Type ramp
    enum Typography {
        static func title() -> Font { .system(.largeTitle, design: .serif).weight(.regular) }
        static func sectionTitle() -> Font { .system(.title3, design: .serif).weight(.regular) }
        static func body() -> Font { .system(.body, design: .rounded).weight(.regular) }
        static func bodyEmphasis() -> Font { .system(.body, design: .rounded).weight(.medium) }
        static func meta() -> Font { .system(.footnote, design: .rounded).weight(.regular) }
        static func chip() -> Font { .system(.subheadline, design: .rounded).weight(.medium) }
    }

    // MARK: Palette
    enum Palette {
        static let ink = Color.primary
        static let inkSoft = Color.primary.opacity(0.7)
        static let muted = Color.secondary
        static let hairline = Color.primary.opacity(0.08)
        static let paper = Color(uiColor: .secondarySystemBackground)
        static let card = Color(uiColor: .tertiarySystemBackground)

        /// Importance dot colour keyed to the string values used in userInfo.
        static func dot(for importance: String) -> Color {
            switch importance {
            case "low":      return Color.gray.opacity(0.55)
            case "high":     return Color.orange.opacity(0.85)
            case "critical": return Color.red.opacity(0.85)
            default:         return Color.blue.opacity(0.75) // "med"
            }
        }
    }
}
