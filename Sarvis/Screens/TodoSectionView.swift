import SwiftUI

// MARK: - TodoSectionView
//
// Tiled timeline replacement for the flat Todo list under Library → Todo.
// Layout:
//   ┌──────────────────────────────────────┐
//   │            Today (large)             │  ~220pt, full width
//   ├───────────────────┬──────────────────┤
//   │   Tomorrow        │  Near Future     │  ~140pt, half width each
//   └───────────────────┴──────────────────┘
// Each tile is tappable → toggles inline expansion. Expanded tiles show their
// items in a `List` with trailing swipe → mark done. Tapping a row opens
// the edit sheet. The "completed history" navigation icon sits in the
// top-right of this view.
//
// Bucketing rules:
//   - todayItems       — `.task && !isDone && Calendar.isDateInToday(dueAt)`
//   - tomorrowItems    — `.task && !isDone && Calendar.isDateInTomorrow(dueAt)`
//   - nearFutureItems  — `.task && !isDone && dueAt > end-of-tomorrow
//                          && dueAt <= end-of-day(today + 10)`
// All buckets sort by `dueAt` asc, then `importance.rawValue` desc as tiebreak.

struct TodoSectionView: View {
    @EnvironmentObject private var todoStore: TodoStore

    enum TileKey: Hashable { case today, tomorrow, nearFuture, everythingElse }

    @State private var expanded: Set<TileKey> = [.today]
    @State private var editing: TodoItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            header

            tileBox(
                key: .today,
                title: "Today",
                subtitle: TodoSectionView.formattedToday(),
                icon: "sun.max",
                items: todayItems
            )
            tileBox(
                key: .tomorrow,
                title: "Tomorrow",
                subtitle: TodoSectionView.formattedTomorrow(),
                icon: "moon.stars",
                items: tomorrowItems
            )
            tileBox(
                key: .nearFuture,
                title: "Near Future",
                subtitle: "Next 10 days",
                icon: "calendar",
                items: nearFutureItems
            )
            tileBox(
                key: .everythingElse,
                title: "Everything Else",
                subtitle: "Beyond 10 days",
                icon: "tray",
                items: everythingElseItems
            )
        }
        .sheet(item: $editing) { item in
            TodoEditSheet(item: item) { updated in
                todoStore.update(updated)
            }
        }
    }

    // MARK: - Header (title + history navigation icon)

    private var header: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Theme.Palette.muted)
            Text("Todo")
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Palette.ink)

            Spacer()

            NavigationLink {
                CompletedTodosView()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.Palette.muted)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tile box (header + expanded list, all inside one card)

    @ViewBuilder
    private func tileBox(
        key: TileKey,
        title: String,
        subtitle: String,
        icon: String,
        items: [TodoItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            tileHeader(
                key: key,
                title: title,
                subtitle: subtitle,
                icon: icon,
                count: items.count
            )

            if expanded.contains(key) {
                Divider()
                    .background(Theme.Palette.hairline)
                    .padding(.horizontal, Theme.Spacing.md)

                expandedList(items: items)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: 0, cornerRadius: Theme.Radius.card)
        .animation(.easeInOut(duration: 0.22), value: expanded)
    }

    // MARK: - Tile header button

    @ViewBuilder
    private func tileHeader(
        key: TileKey,
        title: String,
        subtitle: String,
        icon: String,
        count: Int
    ) -> some View {
        Button {
            Haptics.soft()
            withAnimation(.easeInOut(duration: 0.22)) {
                if expanded.contains(key) { expanded.remove(key) }
                else { expanded.insert(key) }
            }
        } label: {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Theme.Palette.muted)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .serif).weight(.regular))
                        .foregroundStyle(Theme.Palette.ink)
                    Text(subtitle)
                        .font(Theme.Typography.meta())
                        .foregroundStyle(Theme.Palette.muted)
                }

                Spacer(minLength: 0)

                countPill(count)

                Image(systemName: expanded.contains(key) ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func countPill(_ count: Int) -> some View {
        Text("\(count)")
            .font(Theme.Typography.meta())
            .foregroundStyle(Theme.Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                    )
            )
    }

    // MARK: - Expanded list (List with swipe-done + tap-to-edit)

    private static let rowHeight: CGFloat = 92

    @ViewBuilder
    private func expandedList(items: [TodoItem]) -> some View {
        if items.isEmpty {
            Text("Nothing here yet.")
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Spacing.sm)
        } else {
            List {
                ForEach(items) { item in
                    TodoTaskRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.light()
                            editing = item
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        // Trailing swipe = full-swipe Done (existing behaviour)
                        // PLUS a second trailing destructive Delete button so a
                        // partial swipe reveals both. Mail-style.
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                Haptics.success()
                                todoStore.toggleDone(item.id)
                            } label: {
                                Label("Done", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Haptics.light()
                                todoStore.delete(item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(items.count) * Self.rowHeight)
        }
    }

    // MARK: - Bucketing

    private var todayItems: [TodoItem] {
        let cal = Calendar.current
        return todoStore.items(in: .task)
            .filter { item in
                guard !item.isDone, let due = item.dueAt else { return false }
                return cal.isDateInToday(due)
            }
            .sorted(by: TodoSectionView.taskSort)
    }

    private var tomorrowItems: [TodoItem] {
        let cal = Calendar.current
        return todoStore.items(in: .task)
            .filter { item in
                guard !item.isDone, let due = item.dueAt else { return false }
                return cal.isDateInTomorrow(due)
            }
            .sorted(by: TodoSectionView.taskSort)
    }

    private var nearFutureItems: [TodoItem] {
        let cal = Calendar.current
        let now = Date()
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
              let endOfTomorrow = cal.date(bySettingHour: 23, minute: 59, second: 59, of: tomorrow),
              let tenAhead = cal.date(byAdding: .day, value: 10, to: now),
              let endOfTenAhead = cal.date(bySettingHour: 23, minute: 59, second: 59, of: tenAhead)
        else { return [] }
        return todoStore.items(in: .task)
            .filter { item in
                guard !item.isDone, let due = item.dueAt else { return false }
                return due > endOfTomorrow && due <= endOfTenAhead
            }
            .sorted(by: TodoSectionView.taskSort)
    }

    private var everythingElseItems: [TodoItem] {
        let cal = Calendar.current
        let now = Date()
        guard let tenAhead = cal.date(byAdding: .day, value: 10, to: now),
              let endOfTenAhead = cal.date(bySettingHour: 23, minute: 59, second: 59, of: tenAhead)
        else { return [] }
        return todoStore.items(in: .task)
            .filter { item in
                guard !item.isDone else { return false }
                guard let due = item.dueAt else { return true }
                return due > endOfTenAhead
            }
            .sorted(by: TodoSectionView.taskSort)
    }

    private static func taskSort(_ lhs: TodoItem, _ rhs: TodoItem) -> Bool {
        let l = lhs.dueAt ?? .distantFuture
        let r = rhs.dueAt ?? .distantFuture
        if l != r { return l < r }
        return lhs.importance.rawValue > rhs.importance.rawValue
    }

    // MARK: - Date formatting helpers

    private static func formattedToday() -> String {
        Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private static func formattedTomorrow() -> String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return tomorrow.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

// MARK: - TodoTaskRow
//
// Single-row visual used inside an expanded tile. Mirrors `ReadOnlyTodoRow`
// styling but is List-row-friendly: no Button wrapper, so the `.swipeActions`
// gesture isn't competing with a button hit-area, and an `.onTapGesture` on
// the row container drives the edit-sheet.

struct TodoTaskRow: View {
    let item: TodoItem

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm + 2) {
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
                    Text(due.formatted(date: .abbreviated, time: .shortened))
                }
                .foregroundStyle(Theme.Palette.muted)
            }
        }
        .font(Theme.Typography.meta())
    }
}

// MARK: - TodoEditSheet
//
// Presented when a task row is tapped. Edits text / importance / sensitive
// flag / due date. Date is mandatory for tasks (no clear toggle). Save calls
// `todoStore.update(_:)`.

struct TodoEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: TodoItem
    let onSave: (TodoItem) -> Void

    @Namespace private var importanceNS
    @FocusState private var editorFocused: Bool

    init(item: TodoItem, onSave: @escaping (TodoItem) -> Void) {
        // Ensure due date is non-nil for editing (UI invariant for tasks).
        var seed = item
        if seed.dueAt == nil {
            let cal = Calendar.current
            seed.dueAt = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        _item = State(initialValue: seed)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.LayeredBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        editorCard
                        importanceRow
                        sensitiveAndDate
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
                .scrollDismissesKeyboard(.immediately)
                .dismissKeyboardToolbar()
            }
            .navigationTitle("Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        Haptics.light()
                        dismiss()
                    }
                    .foregroundStyle(Theme.Palette.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.success()
                        onSave(item)
                        dismiss()
                    }
                    .foregroundStyle(Theme.Palette.ink)
                    .disabled(item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var editorCard: some View {
        ZStack(alignment: .topLeading) {
            if item.text.isEmpty {
                Text("Task")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.Palette.muted.opacity(0.7))
                    .padding(.top, 8)
                    .padding(.leading, 6)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $item.text)
                .font(.system(.title3, design: .serif))
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .frame(minHeight: 120, maxHeight: 200)
                .tint(Theme.Palette.ink)
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.hero)
    }

    private var importanceRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            label("Importance")
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Importance.allCases) { imp in
                    EditImportanceChip(
                        importance: imp,
                        isSelected: item.importance == imp,
                        ns: importanceNS
                    ) {
                        Haptics.soft()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            item.importance = imp
                        }
                    }
                }
            }
        }
    }

    private var sensitiveAndDate: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                EditLockPill(isOn: $item.isSensitive)
                Spacer()
            }

            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.muted)
                Text("Due")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Palette.inkSoft)
                Spacer()
                DatePicker(
                    "",
                    selection: Binding(
                        get: { item.dueAt ?? Date() },
                        set: { item.dueAt = $0 }
                    )
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
            .themedCard(padding: Theme.Spacing.sm + 4,
                        cornerRadius: Theme.Radius.card)
        }
    }

    @ViewBuilder
    private func label(_ s: String) -> some View {
        Text(s.uppercased())
            .font(Theme.Typography.meta())
            .tracking(1)
            .foregroundStyle(Theme.Palette.muted)
    }
}

// MARK: - Edit-sheet local chip / pill
//
// Mirrors the visual of `ImportanceChip` / `LockPill` from `InputView` (those
// are file-private). Kept local to this file so the edit sheet doesn't need
// to depend on InputView's internals.

private struct EditImportanceChip: View {
    let importance: Importance
    let isSelected: Bool
    var ns: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: importance.symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(importance.label)
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : Theme.Palette.inkSoft)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(Theme.Palette.ink)
                        .matchedGeometryEffect(id: "editImportanceIndicator", in: ns)
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        }
        .buttonStyle(.plain)
    }
}

private struct EditLockPill: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "lock.fill" : "lock.open")
                    .font(.system(size: 12, weight: .medium))
                Text(isOn ? "Sensitive" : "Private?")
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isOn ? Color.red.opacity(0.9) : Theme.Palette.muted)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(isOn ? Theme.Palette.sensitiveTint : Color.clear)
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(isOn ? 0 : 1)
            }
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isOn ? Color.red.opacity(0.3) : Theme.Palette.hairline,
                                  lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CompletedTodosView
//
// Pushed via NavigationLink from the todo section header. Lists every
// `.task` item with `isDone == true`, sorted by `completedAt` desc with
// `createdAt` desc fallback for legacy items. Trailing-swipe → "Revert"
// flips the item back to undone (clearing `completedAt`).

struct CompletedTodosView: View {
    @EnvironmentObject private var todoStore: TodoStore

    var body: some View {
        ZStack {
            Theme.LayeredBackground()

            if completed.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(completed) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            TodoTaskRow(item: item)
                            if let stamp = item.completedAt {
                                Text("Completed \(stamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(Theme.Typography.meta())
                                    .foregroundStyle(Theme.Palette.muted)
                                    .padding(.leading, Theme.Spacing.sm)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                Haptics.soft()
                                todoStore.toggleDone(item.id)
                            } label: {
                                Label("Revert", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Haptics.light()
                                todoStore.delete(item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Completed")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var completed: [TodoItem] {
        todoStore.items(in: .task)
            .filter { $0.isDone }
            .sorted { lhs, rhs in
                let l = lhs.completedAt ?? lhs.createdAt
                let r = rhs.completedAt ?? rhs.createdAt
                return l > r
            }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer(minLength: Theme.Spacing.xl)
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(Theme.Palette.muted.opacity(0.5))
            Text("Nothing completed yet.")
                .font(Theme.Typography.emptyState())
                .foregroundStyle(Theme.Palette.inkSoft)
            Text("Swipe a task to mark it done — it'll show up here.")
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            TodoSectionView()
                .padding()
        }
    }
    .environmentObject(TodoStore.shared)
}
