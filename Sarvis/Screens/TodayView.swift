import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: TodoStore

    // Group items by start-of-day of createdAt, sorted descending
    private var groupedItems: [(dayKey: Date, items: [TodoItem])] {
        let sorted = store.items.sorted { $0.createdAt > $1.createdAt }
        let cal = Calendar.current
        var dict: [Date: [TodoItem]] = [:]
        for item in sorted {
            let key = cal.startOfDay(for: item.createdAt)
            dict[key, default: []].append(item)
        }
        return dict
            .sorted { $0.key > $1.key }
            .map { (dayKey: $0.key, items: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.LayeredBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header

                        if store.items.isEmpty {
                            emptyState
                        } else {
                            ForEach(groupedItems, id: \.dayKey) { group in
                                daySection(dayKey: group.dayKey, items: group.items)
                            }
                        }

                        // Bottom space for the floating tab bar
                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Entries")
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Palette.ink)
            Text("Everything you've captured.")
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Spacer(minLength: Theme.Spacing.xxl)
            Text("Nothing captured yet")
                .font(Theme.Typography.emptyState())
                .foregroundStyle(Theme.Palette.inkSoft)
            Text("Capture something on the other tab — or simply rest.")
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
                .multilineTextAlignment(.center)
            Spacer(minLength: Theme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xl)
    }

    // MARK: Day section
    @ViewBuilder
    private func daySection(dayKey: Date, items: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(Self.sectionTitle(for: dayKey))
                .font(Theme.Typography.sectionTitle())
                .foregroundStyle(Theme.Palette.inkSoft)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(items) { TodoRow(item: $0) }
            }
        }
    }

    // MARK: Section title helpers
    private static func sectionTitle(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        let now = Date()
        if let diff = cal.dateComponents([.day], from: day, to: now).day, diff < 7 {
            let df = DateFormatter()
            df.dateFormat = "EEEE"
            return df.string(from: day)
        }
        let nowYear = cal.component(.year, from: now)
        let dayYear = cal.component(.year, from: day)
        let df = DateFormatter()
        if dayYear == nowYear {
            df.dateFormat = "MMM d"
        } else {
            df.dateFormat = "MMM d, yyyy"
        }
        return df.string(from: day)
    }
}

// MARK: - TodoRow (floating card)
struct TodoRow: View {
    let item: TodoItem
    @EnvironmentObject var store: TodoStore
    @State private var pressed: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm + 2) {
            Button {
                Haptics.soft()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    store.toggleDone(item.id)
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(item.isDone ? Color.clear : Theme.Palette.muted.opacity(0.55),
                                      lineWidth: 1.2)
                        .frame(width: 22, height: 22)
                    if item.isDone {
                        Circle()
                            .fill(Theme.Palette.ink)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(uiColor: .systemBackground))
                    }
                }
                .padding(.top, 2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(item.isDone ? Theme.Palette.ink.opacity(0.4) : Theme.Palette.ink)
                    .strikethrough(item.isDone, color: Theme.Palette.ink.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)

                metaRow
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Palette.muted.opacity(0.5))
                .padding(.top, 4)
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                if let nid = item.notificationID {
                    NotificationService.shared.cancel(nid)
                }
                store.delete(item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
        }
        .font(Theme.Typography.meta())
    }
}

#Preview {
    TodayView().environmentObject(TodoStore.shared)
}
