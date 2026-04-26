# Processed Viewer Screen — output

## Section taxonomy

| Section     | Store / API                                     | Sort / group                                 |
|-------------|--------------------------------------------------|----------------------------------------------|
| Today       | `TodoStore.shared.todayItems`                   | By importance desc; sensitive group first    |
| Notes       | `TodoStore.shared.items(in: .note)`             | `createdAt` desc                             |
| Shopping    | `TodoStore.shared.items(in: .shopping)`         | Flat list (see urgency gap below)            |
| Diary       | `TodoStore.shared.items(in: .diary)`            | `createdAt` desc                             |
| Ideas       | `TodoStore.shared.items(in: .idea)`             | `createdAt` desc                             |
| Suggestions | `TodoStore.shared.items(in: .suggestion)`       | `createdAt` desc                             |
| Quotes      | `QuoteService.shared.loadAll()`                 | Insertion order (seed + accumulated)         |
| News        | `NewsService.shared.articlesForToday()` (cache) | Insertion order; refresh button hits network |
| Profile     | `ProfileStore.shared.profile`                   | Preferences sorted by key; traits in order   |

## New display elements

Each lives under `Sarvis/UI/Elements/Display/<Name>/<Name>View.swift` and is registered in `ElementRegistry.registerBuiltIns()`.

| Element           | Registry key               | Standalone type       | Used by         |
|-------------------|----------------------------|-----------------------|-----------------|
| TodoListRow       | `Display/TodoListRow`      | `ReadOnlyTodoRow`     | ProcessedView   |
| NotesListRow      | `Display/NotesListRow`     | `NoteCard`            | ProcessedView   |
| ShoppingListRow   | `Display/ShoppingListRow`  | `ShoppingItemCard`    | ProcessedView   |
| DiaryEntry        | `Display/DiaryEntry`       | `DiaryCard`           | ProcessedView   |
| QuoteCard         | `Display/QuoteCard`        | `QuoteDisplayCard`    | ProcessedView   |
| NewsHeadline      | `Display/NewsHeadline`     | `NewsHeadlineCard`    | ProcessedView   |

The composer registry stubs (`struct XxxView: View`) render `EmptyView` — they exist only to satisfy the registry contract. The real rendering happens via the standalone types which `ProcessedView` calls directly (same pattern as `TodoRow` in `TodayView`).

## Shopping-urgency-metadata gap

**Problem:** `TodoItem` has no urgency field. The `ShoppingItemView` input element exposes a 4-level urgency picker (`today / nextVisit / thisWeek / someday`) at capture time but has nowhere to persist the selection — it only persists the item `text`.

**MVP workaround (shipped):** `ShoppingUrgency.infer(from:)` in `ShoppingListRowView.swift` applies keyword heuristics on the item text ("today", "next visit", "this week", "someday"). Items without keywords default to `.nextVisit`. This means items are shown flat (not grouped by urgency sub-header) since the inferred urgency is unreliable.

**Proposed fix (separate worker):**
1. Add `metadata: [String: AnyCodableValue]` to `TodoItem` (mirrors `ElementSpec.config`).
2. `ShoppingItemView` writes `metadata["urgency"] = .string(urgency.rawValue)` on save.
3. `ShoppingListRowView` / `ShoppingItemCard` reads `item.metadata["urgency"]` and falls back to inference only when nil.
4. `ProcessedView.shoppingSection` can then group by the stored urgency into 4 sub-headers.

This worker should be tagged `shopping-urgency-metadata` and is a dependency for proper shopping grouping.

## How to add a new section later

1. **Add an enum case** to `ProcessedSection` in `ProcessedView.swift` with a `label` and `symbol`.
2. **Add a `switch` arm** in `ProcessedView.sectionBody` that calls a new `@ViewBuilder var xxxSection: some View`.
3. **Add (optionally) a display element** under `Sarvis/UI/Elements/Display/<Name>/` with a standalone card type and register it in `ElementRegistry.registerBuiltIns()`.

No other files need to change. The section chip picker is driven by `ProcessedSection.allCases` so the new chip appears automatically.

## Files created / modified

### Created
- `Sarvis/UI/Elements/Display/TodoListRow/TodoListRowView.swift`
- `Sarvis/UI/Elements/Display/NotesListRow/NotesListRowView.swift`
- `Sarvis/UI/Elements/Display/ShoppingListRow/ShoppingListRowView.swift`
- `Sarvis/UI/Elements/Display/DiaryEntry/DiaryEntryView.swift`
- `Sarvis/UI/Elements/Display/QuoteCard/QuoteCardView.swift`
- `Sarvis/UI/Elements/Display/NewsHeadline/NewsHeadlineView.swift`
- `Sarvis/Screens/ProcessedView.swift`

### Modified
- `Sarvis/UI/Composer/ElementRegistry.swift` — 6 new `register(...)` calls in `registerBuiltIns()`
- `Sarvis/App/RootView.swift` — added `.library` case to `Tab` enum; added `ProcessedView()` to switch; added Library tab button in `CustomTabBar`
