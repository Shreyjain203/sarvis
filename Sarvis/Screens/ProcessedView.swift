import SwiftUI

// MARK: - Section model

enum ProcessedSection: String, CaseIterable, Identifiable {
    case today      = "today"
    case notes      = "notes"
    case shopping   = "shopping"
    case diary      = "diary"
    case ideas      = "ideas"
    case suggestions = "suggestions"
    case quotes     = "quotes"
    case news       = "news"
    case profile    = "profile"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:       return "Today"
        case .notes:       return "Notes"
        case .shopping:    return "Shopping"
        case .diary:       return "Diary"
        case .ideas:       return "Ideas"
        case .suggestions: return "Suggestions"
        case .quotes:      return "Quotes"
        case .news:        return "News"
        case .profile:     return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .today:       return "leaf"
        case .notes:       return "doc.text"
        case .shopping:    return "cart"
        case .diary:       return "book.closed"
        case .ideas:       return "lightbulb"
        case .suggestions: return "sparkles"
        case .quotes:      return "quote.bubble"
        case .news:        return "newspaper"
        case .profile:     return "person.circle"
        }
    }
}

// MARK: - ProcessedView

struct ProcessedView: View {
    @EnvironmentObject private var todoStore: TodoStore
    @StateObject private var profileStore = ProfileStore.shared

    @State private var selectedSection: ProcessedSection = .today
    @Namespace private var processedSectionNS

    // News: read from DailyArtifactStore + allow refresh
    @State private var newsArticles: [NewsArticle]? = nil
    @State private var isRefreshingNews = false
    @State private var newsError: String? = nil

    // Quotes: synchronous load (no async needed, file-backed)
    @State private var quotes: [Quote] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.LayeredBackground()

                VStack(spacing: 0) {
                    sectionPicker
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.sm)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                            sectionBody
                            // Bottom space for the floating tab bar
                            Color.clear.frame(height: 96)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.sm)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadQuotes()
            loadNews()
        }
    }

    // MARK: - Section picker (horizontal chip scroll)

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(ProcessedSection.allCases) { section in
                    sectionChip(section)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionChip(_ section: ProcessedSection) -> some View {
        let isActive = selectedSection == section
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: section.symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(section.label)
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isActive
                             ? Color(uiColor: .systemBackground)
                             : Theme.Palette.inkSoft)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(Theme.Palette.ink)
                        .matchedGeometryEffect(id: "processedSectionIndicator",
                                               in: processedSectionNS)
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

    // MARK: - Section body dispatcher

    @ViewBuilder
    private var sectionBody: some View {
        switch selectedSection {
        case .today:       todaySection
        case .notes:       notesSection
        case .shopping:    shoppingSection
        case .diary:       diarySection
        case .ideas:       ideasSection
        case .suggestions: suggestionsSection
        case .quotes:      quotesSection
        case .news:        newsSection
        case .profile:     profileSection
        }
    }

    // MARK: - Today

    private var todaySection: some View {
        let items = todoStore.todayItems
        return Group {
            sectionHeader("Today", symbol: "leaf")
            if items.isEmpty {
                emptyState(icon: "leaf", message: "Nothing due today",
                           detail: "Capture something on the Capture tab.")
            } else {
                // Sensitive items first
                let sensitive = items.filter { $0.isSensitive }
                if !sensitive.isEmpty {
                    sensitiveSectionBlock(sensitive)
                }
                // Then group by importance (high → low)
                ForEach(Importance.allCases.reversed()) { imp in
                    let group = items.filter { $0.importance == imp && !$0.isSensitive }
                    if !group.isEmpty {
                        importanceGroupBlock(imp, items: group)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sensitiveSectionBlock(_ items: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Sensitive")
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(Theme.Palette.sensitiveAccent)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(items) { ReadOnlyTodoRow(item: $0) }
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
        }
    }

    @ViewBuilder
    private func importanceGroupBlock(_ imp: Importance, items: [TodoItem]) -> some View {
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
                ForEach(items) { ReadOnlyTodoRow(item: $0) }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        let items = todoStore.items(in: .note)
            .sorted { $0.createdAt > $1.createdAt }
        return Group {
            sectionHeader("Notes", symbol: "doc.text")
            if items.isEmpty {
                emptyState(icon: "doc.text", message: "No notes yet",
                           detail: "Capture a note on the Capture tab.")
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(items) { NoteCard(item: $0) }
                }
            }
        }
    }

    // MARK: - Shopping
    //
    // Shopping-urgency-metadata gap (MVP):
    // `TodoItem` has no explicit urgency field, so urgency is inferred from item text
    // via `ShoppingUrgency.infer(from:)`. This is a heuristic — items without keywords
    // default to `.nextVisit`. A proper fix requires a `metadata: [String: AnyCodableValue]`
    // field on `TodoItem` so `ShoppingItemView` can write `metadata["urgency"]` at capture
    // time. This is tracked in `.dispatch/tasks/processed-viewer-screen/output.md`.
    // TODO: refactor TodoItem to add metadata; remove inference heuristic.

    private var shoppingSection: some View {
        let items = todoStore.items(in: .shopping)
        return Group {
            sectionHeader("Shopping", symbol: "cart")
            if items.isEmpty {
                emptyState(icon: "cart", message: "Shopping list is empty",
                           detail: "Add items on the Capture tab.")
            } else {
                // Flat list for MVP (urgency grouping blocked by metadata gap — see above)
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(items) { ShoppingItemCard(item: $0) }
                }
            }
        }
    }

    // MARK: - Diary

    private var diarySection: some View {
        let items = todoStore.items(in: .diary)
            .sorted { $0.createdAt > $1.createdAt }
        return Group {
            sectionHeader("Diary", symbol: "book.closed")
            if items.isEmpty {
                emptyState(icon: "book.closed", message: "No diary entries yet",
                           detail: "Write your first diary entry on the Capture tab.")
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(items) { DiaryCard(item: $0) }
                }
            }
        }
    }

    // MARK: - Ideas

    private var ideasSection: some View {
        let items = todoStore.items(in: .idea)
            .sorted { $0.createdAt > $1.createdAt }
        return Group {
            sectionHeader("Ideas", symbol: "lightbulb")
            if items.isEmpty {
                emptyState(icon: "lightbulb", message: "No ideas captured yet",
                           detail: "Brain-dump on the Capture tab.")
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(items) { NoteCard(item: $0) }
                }
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        let items = todoStore.items(in: .suggestion)
            .sorted { $0.createdAt > $1.createdAt }
        return Group {
            sectionHeader("Suggestions", symbol: "sparkles")
            if items.isEmpty {
                emptyState(icon: "sparkles", message: "No suggestions yet",
                           detail: "Sarvis will surface suggestions as you use the app.")
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(items) { NoteCard(item: $0) }
                }
            }
        }
    }

    // MARK: - Quotes

    private var quotesSection: some View {
        Group {
            sectionHeader("Quotes", symbol: "quote.bubble")
            if quotes.isEmpty {
                emptyState(icon: "quote.bubble", message: "No quotes loaded",
                           detail: "Quotes from seed.json will appear here.")
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(quotes, id: \.text) { QuoteDisplayCard(quote: $0) }
                }
            }
        }
    }

    // MARK: - News

    private var newsSection: some View {
        Group {
            sectionHeader("News", symbol: "newspaper")
            if isRefreshingNews {
                ProgressView("Fetching news…")
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xl)
                    .foregroundStyle(Theme.Palette.muted)
            } else if let articles = newsArticles, !articles.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(articles) { NewsHeadlineCard(article: $0) }
                }
            } else {
                newsEmptyState
            }
        }
    }

    private var newsEmptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer(minLength: Theme.Spacing.xxl)
            Image(systemName: "newspaper")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(Theme.Palette.muted.opacity(0.5))

            Text("No briefing yet")
                .font(Theme.Typography.emptyState())
                .foregroundStyle(Theme.Palette.inkSoft)

            if let err = newsError {
                Text(err)
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.sensitiveAccent)
                    .multilineTextAlignment(.center)
            } else {
                Text("Pull to refresh or tap below to fetch today's headlines.")
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.muted)
                    .multilineTextAlignment(.center)
            }

            Button {
                refreshNews()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                    Text("Refresh news")
                        .font(Theme.Typography.chip())
                }
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                        )
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: Theme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Profile
    //
    // TODO: editable profile — currently read-only. Add a ProfileEditView and wire it here.

    private var profileSection: some View {
        let p = profileStore.profile
        return Group {
            sectionHeader("Profile", symbol: "person.circle")

            // Preferences
            if p.preferences.isEmpty {
                emptyState(icon: "person.circle", message: "No profile data yet",
                           detail: "Sarvis infers your preferences as you capture.")
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    subSectionLabel("Preferences")
                    VStack(spacing: 1) {
                        ForEach(p.preferences.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Text(key)
                                    .font(Theme.Typography.meta())
                                    .foregroundStyle(Theme.Palette.muted)
                                    .frame(width: 110, alignment: .leading)
                                Text(value)
                                    .font(Theme.Typography.body())
                                    .foregroundStyle(Theme.Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                            if key != p.preferences.sorted(by: { $0.key < $1.key }).last?.key {
                                Divider()
                                    .background(Theme.Palette.hairline)
                            }
                        }
                    }
                    .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
                }

                if !p.traits.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        subSectionLabel("Traits")
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            ForEach(p.traits, id: \.self) { trait in
                                HStack(spacing: Theme.Spacing.xs) {
                                    Circle()
                                        .fill(Theme.Palette.muted.opacity(0.5))
                                        .frame(width: 4, height: 4)
                                    Text(trait)
                                        .font(Theme.Typography.body())
                                        .foregroundStyle(Theme.Palette.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
                    }
                }

                Text("Updated \(p.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.muted)
                    .padding(.leading, Theme.Spacing.xs)
            }
        }
    }

    // MARK: - Reusable sub-components

    @ViewBuilder
    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Theme.Palette.muted)
            Text(title)
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Palette.ink)
        }
    }

    @ViewBuilder
    private func subSectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.Typography.meta())
            .tracking(1)
            .foregroundStyle(Theme.Palette.muted)
    }

    @ViewBuilder
    private func emptyState(icon: String, message: String, detail: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer(minLength: Theme.Spacing.xl)
            Image(systemName: icon)
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(Theme.Palette.muted.opacity(0.5))

            Text(message)
                .font(Theme.Typography.emptyState())
                .foregroundStyle(Theme.Palette.inkSoft)

            Text(detail)
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
                .multilineTextAlignment(.center)

            Spacer(minLength: Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Data loading

    private func loadQuotes() {
        Task { @MainActor in
            quotes = QuoteService.shared.loadAll()
        }
    }

    private func loadNews() {
        newsArticles = NewsService.shared.articlesForToday()
    }

    private func refreshNews() {
        isRefreshingNews = true
        newsError = nil
        Task { @MainActor in
            do {
                let articles = try await NewsService.shared.refreshToday()
                newsArticles = articles
            } catch {
                newsError = error.localizedDescription
            }
            isRefreshingNews = false
        }
    }
}

#Preview {
    ProcessedView()
        .environmentObject(TodoStore.shared)
}
