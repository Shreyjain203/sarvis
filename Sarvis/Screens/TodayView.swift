import SwiftUI

struct TodayView: View {
    @ObservedObject private var rawStore: RawStore = .shared

    /// Source list = unprocessed raw entries, newest first, grouped by start-of-day
    /// of `capturedAt`. The classifier is the only path off this list — once it
    /// flips `processed = true`, the entry disappears here and surfaces in the
    /// matching Library tab.
    private var groupedEntries: [(dayKey: Date, entries: [RawEntry])] {
        let unprocessed = rawStore.entries
            .filter { !$0.processed }
            .sorted { $0.capturedAt > $1.capturedAt }
        let cal = Calendar.current
        var dict: [Date: [RawEntry]] = [:]
        for entry in unprocessed {
            let key = cal.startOfDay(for: entry.capturedAt)
            dict[key, default: []].append(entry)
        }
        return dict
            .sorted { $0.key > $1.key }
            .map { (dayKey: $0.key, entries: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.LayeredBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header

                        if groupedEntries.isEmpty {
                            emptyState
                        } else {
                            ForEach(groupedEntries, id: \.dayKey) { group in
                                daySection(dayKey: group.dayKey, entries: group.entries)
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
            Text("Captures waiting to be processed.")
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Spacer(minLength: Theme.Spacing.xxl)
            Text("Nothing waiting to be processed.")
                .font(Theme.Typography.emptyState())
                .foregroundStyle(Theme.Palette.inkSoft)
            Text("Capture something on the other tab — or tap Process to classify what's here.")
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
    private func daySection(dayKey: Date, entries: [RawEntry]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(Self.sectionTitle(for: dayKey))
                .font(Theme.Typography.sectionTitle())
                .foregroundStyle(Theme.Palette.inkSoft)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(entries) { RawEntryRow(entry: $0) }
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

// MARK: - RawEntryRow (floating card for a not-yet-processed capture)
struct RawEntryRow: View {
    let entry: RawEntry

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm + 2) {
            // No checkbox — raws aren't TodoItems yet.
            Image(systemName: "circle.dotted")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Palette.muted.opacity(0.55))
                .frame(width: 22, height: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                metaRow
            }

            Spacer(minLength: 0)
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                if let nid = entry.notificationID {
                    NotificationService.shared.cancel(nid)
                }
                RawStore.shared.delete(entry.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.Palette.dot(for: entry.importance))
                    .frame(width: 5, height: 5)
                Text(entry.importance.label)
            }
            .foregroundStyle(Theme.Palette.muted)

            if let suggested = entry.suggestedType {
                HStack(spacing: 4) {
                    Image(systemName: suggested.symbol)
                        .font(.system(size: 9))
                    Text(suggested.label)
                }
                .foregroundStyle(Theme.Palette.muted)
            }

            if entry.isSensitive {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text("Sensitive")
                }
                .foregroundStyle(Theme.Palette.sensitiveAccent)
            }

            Text(entry.capturedAt.formatted(date: .omitted, time: .shortened))
                .foregroundStyle(Theme.Palette.muted)
        }
        .font(Theme.Typography.meta())
    }
}

#Preview {
    TodayView()
}
