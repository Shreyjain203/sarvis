import SwiftUI

/// A single `TodoItem` display row. Reuses the `TodoRow` visual from `TodayView`
/// directly (same importance dot, check button, meta row). Read-only affordances
/// only — no delete swipe action.
/// Registers as `"Display/TodoListRow"`.
struct TodoListRowView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    // This element is used as a thin wrapper; actual rendering delegates to TodoRow.
    // When used standalone (e.g., in ProcessedView), pass the item directly via init below.
    var body: some View {
        // This view is used via the composer registry; it has no meaningful
        // standalone rendering without an item ref. A no-op placeholder keeps
        // the registry happy while ProcessedView uses TodoRow directly.
        EmptyView()
    }
}

// MARK: - Standalone read-only row (used by ProcessedView directly)

/// Read-only variant of TodoRow — no delete swipe, no toggle (view-only context).
struct ReadOnlyTodoRow: View {
    let item: TodoItem

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm + 2) {
            // Importance dot column
            Circle()
                .fill(Theme.Palette.dot(for: item.importance))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(item.isDone
                                     ? Theme.Palette.ink.opacity(0.4)
                                     : Theme.Palette.ink)
                    .strikethrough(item.isDone, color: Theme.Palette.ink.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)

                metaRow
            }

            Spacer(minLength: 0)
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.Palette.dot(for: item.importance))
                    .frame(width: 5, height: 5)
                Text(item.importance.label)
            }
            .foregroundStyle(Theme.Palette.muted)

            if item.isSensitive {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text("Sensitive")
                }
                .foregroundStyle(Theme.Palette.sensitiveAccent)
            }

            if let due = item.dueAt {
                HStack(spacing: 4) {
                    Image(systemName: "bell")
                        .font(.system(size: 9))
                    Text(due.formatted(date: .omitted, time: .shortened))
                }
                .foregroundStyle(Theme.Palette.muted)
            }

            Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(Theme.Palette.muted)
        }
        .font(Theme.Typography.meta())
    }
}
