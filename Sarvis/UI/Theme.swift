import SwiftUI
import UIKit

/// Centralised design tokens. Keep this file the single source of truth
/// for spacing, radii, fonts, palette and reusable layered backgrounds.
enum Theme {
    // MARK: Spacing scale (4-pt base, 8-pt rhythm)
    enum Spacing {
        static let hair: CGFloat = 2
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Corner radii
    enum Radius {
        static let chip: CGFloat = 12
        static let card: CGFloat = 20
        static let hero: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: Type ramp — restrained serif headings, rounded body
    enum Typography {
        // Editorial serifs for headings and hero numerals
        static func display() -> Font { .system(size: 40, weight: .regular, design: .serif) }
        static func title() -> Font { .system(.largeTitle, design: .serif).weight(.regular) }
        static func sectionTitle() -> Font { .system(.title3, design: .serif).weight(.regular) }
        static func emptyState() -> Font { .system(.title2, design: .serif).weight(.regular) }

        // Soft rounded for UI chrome and buttons
        static func body() -> Font { .system(.body, design: .rounded).weight(.regular) }
        static func bodyEmphasis() -> Font { .system(.body, design: .rounded).weight(.medium) }
        static func meta() -> Font { .system(.footnote, design: .rounded).weight(.regular) }
        static func chip() -> Font { .system(.subheadline, design: .rounded).weight(.medium) }
        static func tab() -> Font { .system(.callout, design: .rounded).weight(.semibold) }
    }

    // MARK: Palette — derived from semantic colours so dark mode is intentional
    enum Palette {
        static let ink = Color.primary
        static let inkSoft = Color.primary.opacity(0.7)
        static let muted = Color.secondary
        static let hairline = Color.primary.opacity(0.08)

        /// Soft paper tint for the editor surface (light) / near-black (dark).
        static let paper = Color(uiColor: .secondarySystemBackground)

        /// Card surface when not using ultraThinMaterial.
        static let card = Color(uiColor: .tertiarySystemBackground)

        // Importance dots — saturated but desaturated enough to stay classy
        static func dot(for importance: Importance) -> Color {
            switch importance {
            case .low: return Color.gray.opacity(0.55)
            case .medium: return Color.blue.opacity(0.75)
            case .high: return Color.orange.opacity(0.85)
            case .critical: return Color.red.opacity(0.85)
            }
        }

        // Subtle red used for sensitive cards — refined, not alarming
        static let sensitiveTint = Color.red.opacity(0.10)
        static let sensitiveAccent = Color.red.opacity(0.7)
    }

    // MARK: Layered backgrounds
    /// Soft layered gradient that adapts to dark / light. Place at the root of every screen.
    struct LayeredBackground: View {
        var body: some View {
            ZStack {
                Color(uiColor: .systemBackground)
                LinearGradient(
                    colors: [
                        Color(uiColor: .secondarySystemBackground).opacity(0.9),
                        Color(uiColor: .systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Faint warm wash, top-left
                RadialGradient(
                    colors: [Color.orange.opacity(0.05), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 420
                )
                // Faint cool wash, bottom-right
                RadialGradient(
                    colors: [Color.blue.opacity(0.05), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Card modifier
    struct CardStyle: ViewModifier {
        var padding: CGFloat = Theme.Spacing.md
        var cornerRadius: CGFloat = Theme.Radius.card
        var useMaterial: Bool = true

        func body(content: Content) -> some View {
            content
                .padding(padding)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(useMaterial ? 1 : 0)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.Palette.card)
                        .opacity(useMaterial ? 0 : 1)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
        }
    }
}

extension View {
    /// Apply the standard floating card treatment.
    func themedCard(padding: CGFloat = Theme.Spacing.md,
                    cornerRadius: CGFloat = Theme.Radius.card,
                    useMaterial: Bool = true) -> some View {
        modifier(Theme.CardStyle(padding: padding,
                                 cornerRadius: cornerRadius,
                                 useMaterial: useMaterial))
    }
}

// MARK: Haptics — keep this here so views just call `Haptics.soft()`.
enum Haptics {
    static func soft() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare()
        g.impactOccurred()
    }

    static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    }

    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.success)
    }
}
