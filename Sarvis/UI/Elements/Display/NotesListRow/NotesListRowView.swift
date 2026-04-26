import SwiftUI

/// A themed card showing one note's text and captured date.
/// Registers as `"Display/NotesListRow"`.
struct NotesListRowView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    var body: some View {
        EmptyView()
    }
}

// MARK: - Standalone note card (used by ProcessedView directly)

struct NoteCard: View {
    let item: TodoItem

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(item.text)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                Text(Self.dateFormatter.string(from: item.createdAt))
            }
            .font(Theme.Typography.meta())
            .foregroundStyle(Theme.Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }
}
