import SwiftUI

/// A serif-quoted text card with author attribution.
/// Registers as `"Display/QuoteCard"`.
struct QuoteCardView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    var body: some View {
        EmptyView()
    }
}

// MARK: - Standalone quote card (used by ProcessedView directly)

struct QuoteDisplayCard: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Opening quote glyph
            Text("\u{201C}")
                .font(.system(size: 40, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Palette.ink.opacity(0.15))
                .padding(.bottom, -Theme.Spacing.md)

            Text(quote.text)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .italic()

            if let author = quote.author, !author.isEmpty {
                Text("— \(author)")
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }
}
