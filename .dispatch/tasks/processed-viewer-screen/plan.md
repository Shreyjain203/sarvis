# Processed viewer screen

A second main tab showing every processed bucket: todos, notes, shopping (grouped by urgency), diary, ideas, suggestions, quotes, news (latest), profile (read-only). Built on the dynamic UI composer where it makes sense; uses purpose-built display elements where it doesn't.

**Layout idea:** segmented picker (Today / Notes / Shopping / Diary / News / Profile / More) at the top, body swaps based on selection. Each section is a small hand-rolled view that reads from the appropriate store and renders with `Theme` styling consistent with `TodayView`.

- [x] **Add display elements** under `Sarvis/UI/Elements/Display/` (each in its own folder, registered in `ElementRegistry.registerBuiltIns()` adjacent to existing `SummaryCard` and `ActionButton` registrations):
  - `TodoListRow/TodoListRowView.swift` — `ReadOnlyTodoRow` standalone (reuses TodoRow visual idiom; no duplicate). Composer stub `TodoListRowView` renders EmptyView.
  - `NotesListRow/NotesListRowView.swift` — `NoteCard` standalone + `NotesListRowView` composer stub.
  - `ShoppingListRow/ShoppingListRowView.swift` — `ShoppingItemCard` + `ShoppingUrgency` enum with urgency heuristic + MVP gap TODO comment.
  - `DiaryEntry/DiaryEntryView.swift` — `DiaryCard` with EEEE date heading.
  - `QuoteCard/QuoteCardView.swift` — `QuoteDisplayCard` with opening quote glyph + italic serif + author.
  - `NewsHeadline/NewsHeadlineView.swift` — `NewsHeadlineCard` with `Link` wrapping full card.
  - All 6 registered in `ElementRegistry.registerBuiltIns()`.
- [x] **Add `Sarvis/Screens/ProcessedView.swift`** — the new tab body:
  - `@StateObject private var todoStore = TodoStore.shared`, `@StateObject private var profileStore = ProfileStore.shared`, plus reads from `DailyArtifactStore` for today's news.
  - `enum ProcessedSection: String, CaseIterable, Identifiable { case today, notes, shopping, diary, ideas, suggestions, quotes, news, profile; var label: String; var symbol: String }`.
  - Top: a horizontal scroll of section chips (reuse the `TypeChip` visual idiom — same palette, same `matchedGeometryEffect` over a fresh `processedSectionNS` namespace).
  - Body: switch on selected section, render the right list:
    - `today` → `TodoStore.shared.todayItems` rendered with `TodoListRowView` per item, grouped by importance (high/med/low headers like in `TodayView`).
    - `notes` → `TodoStore.shared.items(in: .note)` sorted by `createdAt` desc.
    - `shopping` → `TodoStore.shared.items(in: .shopping)` grouped by urgency (4 sub-headers). **Note:** shopping items currently come through `TodoItem` without an explicit urgency field. For this MVP, parse urgency out of the item text or stash it in `TodoItem.note`/extra field if available; if not feasible, show a single flat shopping list and add a TODO comment pointing at the storage gap (`TodoItem` may need a `metadata: [String: AnyCodableValue]` field to carry element-specific data — flag this clearly in output.md).
    - `diary` → `items(in: .diary)`.
    - `ideas` → `items(in: .idea)`.
    - `suggestions` → `items(in: .suggestion)`.
    - `quotes` → `QuoteService.shared.loadAll()` (seed + Documents).
    - `news` → read today's news summary from `DailyArtifactStore`. If empty, show a muted "No briefing yet — pull to refresh" view with a refresh button that calls `MorningJob.scheduleNext()` (or `NewsService.shared.refreshToday()` directly for instant fetch).
    - `profile` → render `ProfileStore.shared.profile` — "Preferences" key/value list + "Traits" bullet list. Read-only for now; add a "// TODO: editable profile" comment.
  - Empty-state for every section: muted text + small icon, consistent treatment.
  - Apply `Theme.LayeredBackground()` and `themedCard()` per the existing visual idiom.
  - Apply `.dismissKeyboardToolbar()` (no input fields here, but consistent).
- [x] **Add the new tab in `Sarvis/App/RootView.swift`:**
  - The current tab bar has 2 tabs (Capture / Today). Add a third: "Library" (or "Processed") with SF Symbol `tray.full`.
  - Reuse the existing capsule tab bar idiom — `matchedGeometryEffect` indicator, `Theme.Spacing` between chips.
  - The order should be: Capture → Today → Library → Settings (if Settings is in the bar; check current code first).
  - Don't break the existing `.onOpenURL` deep link handler that the widget worker added.
- [x] **Verification:** `swift -frontend -parse` on every new + modified file — all clean. `xcodegen generate` exit 0.
- [x] **Update STATE.md** at the project root: moved `processed-viewer-screen` from "Queued / unfinished" to "Build status — shipped"; appended row to dispatched-workers table; added update-log entry; updated architecture map.
- [x] Write a summary to `.dispatch/tasks/processed-viewer-screen/output.md`: section taxonomy, display elements table, store access map, shopping-urgency-metadata gap + proposed fix, how-to-add-a-new-section guide.

**Constraints:**
- iOS 17+. SwiftUI only. No third-party deps.
- Read-only views — don't add edit/delete affordances yet.
- Match the existing visual idiom of `TodayView` (sensitive section, importance dots, themed cards, serif headers).
- Don't touch any file under `SarvisWidget/`, `Sarvis/UI/Elements/Input/`, `Sarvis/UI/Composer/` (other than registering new display elements in `ElementRegistry.registerBuiltIns()`).
- Don't touch `Sarvis/Services/` source — only call existing public APIs.
- The shopping-urgency-metadata gap is OK to flag and ship a flat list for now. Don't refactor `TodoItem` to add a `metadata` field — that's a separate worker.
- Use `Theme` tokens for every spacing / color / radius decision.
