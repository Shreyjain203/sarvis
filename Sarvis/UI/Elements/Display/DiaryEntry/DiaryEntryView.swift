import SwiftUI

/// A themed card with a date heading and diary body text.
/// Registers as `"Display/DiaryEntry"`.
struct DiaryEntryView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    var body: some View {
        EmptyView()
    }
}

// MARK: - Standalone diary card (used by ProcessedView directly)

struct DiaryCard: View {
    let item: TodoItem

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.system(size: 11, weight: .medium))
                Text(Self.dateFormatter.string(from: item.createdAt))
                    .font(Theme.Typography.meta())
                    .tracking(0.3)
            }
            .foregroundStyle(Theme.Palette.muted)

            Text(item.text)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }
}
