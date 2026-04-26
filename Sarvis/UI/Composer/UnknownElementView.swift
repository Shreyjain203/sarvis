import SwiftUI

/// Fallback rendered when a `ScreenDefinition` references an unregistered
/// element type. Makes typos visible rather than silently dropped.
struct UnknownElementView: View {
    let typeName: String

    var body: some View {
        Text("Unknown element: \(typeName)")
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Theme.Palette.muted)
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
    }
}
