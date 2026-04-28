import SwiftUI

/// Notification UI for the `quote.morning` category.
/// Shows: quote body in serif, attribution line, soft accent gradient.
struct QuoteCardView: View {
    let quote: String
    let attribution: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Soft accent wash
            LinearGradient(
                colors: [Color.orange.opacity(0.06), Color.blue.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: ExtensionTheme.Spacing.md) {
                // Opening quote mark
                Text("\u{201C}")
                    .font(.system(size: 52, weight: .regular, design: .serif))
                    .foregroundStyle(ExtensionTheme.Palette.muted.opacity(0.4))
                    .offset(x: -4, y: 0)
                    .frame(height: 28)

                // Quote body
                Text(quote)
                    .font(.system(.title3, design: .serif).weight(.regular))
                    .foregroundStyle(ExtensionTheme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)

                // Attribution
                if !attribution.isEmpty {
                    Text(attribution)
                        .font(ExtensionTheme.Typography.meta())
                        .foregroundStyle(ExtensionTheme.Palette.muted)
                }
            }
            .padding(ExtensionTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
