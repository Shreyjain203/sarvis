import SwiftUI

/// Minimal design tokens for the widget extension.
/// Only contains what QuickCaptureView uses — keep this in sync with Theme.swift.
enum WidgetTheme {
    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
    }

    enum Radius {
        /// Large rounded-rect for the faux text field.
        static let textField: CGFloat = 16
        /// Pill (fully rounded) for the Submit button.
        static let pill: CGFloat = 999
    }

    /// Primary text colour — adapts to dark mode automatically.
    static let ink = Color.primary

    /// Secondary / placeholder text colour.
    static let muted = Color.secondary

    /// Hairline separator / border.
    static let hairline = Color.primary.opacity(0.08)

    /// Warm canvas background (mirrors Theme.Palette warm tones).
    static let canvasBackground = Color(uiColor: .secondarySystemBackground)

    /// Background for the faux input field.
    static let inputBackground = Color(uiColor: .tertiarySystemBackground)

    /// Filled pill button background.
    static let buttonBackground = Color.primary

    /// Filled pill button foreground.
    static let buttonForeground = Color(uiColor: .systemBackground)
}
