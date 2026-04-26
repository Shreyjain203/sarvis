import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: TodoStore

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.LayeredBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header

                        if store.todayItems.isEmpty {
                            emptyState
                        } else {
                            if !store.sensitiveItems.isEmpty {
                                sensitiveSection
                            }

                            ForEach(Importance.allCases.reversed()) { imp in
                                let items = store.todayItems(importance: imp)
                                if !items.isEmpty {
                                    importanceSection(imp, items: items)
                                }
                            }
                        }

                        // Bottom space for the floating tab bar
                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Palette.ink)
            Text(Self.dateFormatter.string(from: Date()))
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Spacer(minLength: Theme.Spacing.xxl)
            Text("Nothing for today")
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

    // MARK: Sensitive section
    private var sensitiveSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Sensitive")
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(Theme.Palette.sensitiveAccent)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(store.sensitiveItems) { item in
                    TodoRow(item: item)
                }
            }
            .padding(Theme.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.sensitiveTint)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.18), lineWidth: 0.5)
            )

            Text("These items were marked sensitive. Don't share casually.")
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
                .padding(.leading, Theme.Spacing.xs)
        }
    }

    // MARK: Importance section
    @ViewBuilder
    private func importanceSection(_ imp: Importance, items: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.Palette.dot(for: imp))
                    .frame(width: 7, height: 7)
                Text(imp.label)
                    .font(Theme.Typography.sectionTitle())
                    .foregroundStyle(Theme.Palette.inkSoft)
            }

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(items) { TodoRow(item: $0) }
            }
        }
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
