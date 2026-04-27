# todo-tiles — output

**Status:** all checklist items completed; build passed; one commit on `worktree-agent-a39601ac` (`982b62d`); no push (per constraints).

## What changed

### Data model + classifier
- `Sarvis/Models/TodoItem.swift` — added `var completedAt: Date?` (Codable-friendly default = nil; legacy files decode cleanly).
- `Sarvis/Models/TodoStore.swift` — `toggleDone(_:)` now stamps `completedAt = Date()` on done and clears it on revert.
- `Sarvis/Services/LLM/ClassifierService.swift` (~L213) — safety net: if `resolvedType == .task && dueDate == nil`, default `dueDate` to today + 7d at 09:00, and append a debug-distribution note `"added (task without dueAt → defaulted to +7d)"`.
- `prompts/capture_classify.md` and `Sarvis/Resources/Prompts/capture_classify.md` — both updated with the always-have-a-date rule for tasks: required `dueAt`, fuzzy-phrase inference table ("soon" → today+1 09:00, "in 7 days" → today+7 09:00, "this/next month" → end-of-month 18:00, "in a few weeks" → today+14 09:00) + 3 worked examples + an explicit Rules-line "Tasks MUST always carry a non-null `dueAt`".

### Todo tiles UI
- New `Sarvis/Screens/TodoSectionView.swift` houses the entire feature: tiles, expanded `List` rows, swipe-done, edit sheet, completed-history view.
- `Sarvis/Screens/ProcessedView.swift` — `todoSection` collapsed to `TodoSectionView()`.
- Tile layout:
  - **Today** — full-width tile, 220pt tall, count badge (top-right pill) + a serif numeral count + "show/hide" chevron, expanded by default.
  - **Tomorrow** + **Near Future** — half-width tiles, 140pt tall each, in an HStack.
- Bucketing (private computed props on `TodoSectionView`):
  - `todayItems` — `.task && !isDone && Calendar.isDateInToday(dueAt)`.
  - `tomorrowItems` — `.task && !isDone && Calendar.isDateInTomorrow(dueAt)`.
  - `nearFutureItems` — `.task && !isDone && dueAt > end-of-tomorrow && dueAt <= end-of-day(today + 10)`.
  - All buckets sort by `dueAt` asc, then `importance.rawValue` desc.
- Expansion uses `@State expanded: Set<TileKey>` with `.easeInOut(duration: 0.22)`. Today is expanded by default.
- Tile face uses `.themedCard(...)` + Theme tokens (no hardcoded colors / radii / spacing).

### Per-task row, swipe-done, edit
- `TodoTaskRow` (in `TodoSectionView.swift`) — same visual idiom as `ReadOnlyTodoRow` but list-row friendly. Tap = `.contentShape(Rectangle()) + .onTapGesture` so the swipe gesture isn't swallowed by a Button.
- Each tile's expanded body is a `List` styled to match the rest of the screen: `.listStyle(.plain)`, `.scrollContentBackground(.hidden)`, `.scrollDisabled(true)`, `Color.clear` row background, hidden separators, fixed total `.frame(height: rowHeight * count)` so it doesn't try to be infinite.
- Swipe-trailing → red "Done" button (`checkmark.circle.fill`), action = `todoStore.toggleDone(item.id)`.
- `TodoEditSheet` — multi-line `TextEditor`, importance chips, lock pill, mandatory `DatePicker` bound through a non-optional `Binding<Date>`. Save → `todoStore.update(_:)`. Cancel/Save in toolbar; Save disabled when text is empty. The sheet seeds `dueAt = today + 1 day` if the item somehow has nil (defensive — every task should already have one).
- Local `EditImportanceChip` / `EditLockPill` mirror the visuals of `InputView`'s file-private `ImportanceChip` / `LockPill` (kept local to avoid coupling).

### Completed history
- `clock.arrow.circlepath` icon in the section header (top-right, themed muted) → `NavigationLink` to `CompletedTodosView` (lives in `TodoSectionView.swift`). Push, not sheet, so swipe-back works.
- `CompletedTodosView` lists `.task && isDone` items, sorted by `completedAt` desc with `createdAt` fallback for legacy items. Each row has a swipe-trailing "Revert" (blue, `arrow.uturn.backward`) → `todoStore.toggleDone(item.id)`. Empty state: "Nothing completed yet."

## Build

`xcodebuild -project Sarvis.xcodeproj -scheme Sarvis -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED** at 09:41:10 on 2026-04-27. Pre-existing SourceKit / `@frozen` warnings unaffected.

## Git

- Branch: `worktree-agent-a39601ac`
- Commit: `982b62d` — "Todo tab: tiled timeline + swipe-done + completed history + edit sheet"
- 8 files changed, 751 insertions(+), 32 deletions(-)
- Not pushed (constraint).

## Notes / decisions

- `CompletedTodosView` lives inside `TodoSectionView.swift` rather than a separate file — it's a single screen tightly coupled to the same row visuals, and keeping it local makes the navigation surface easy to read.
- Tap-to-edit on a row inside a `List` works without competing with `.swipeActions` because the row uses `.contentShape(Rectangle()) + .onTapGesture` (no `Button` wrapper). The List's swipe gesture takes precedence on horizontal drags; tap fires only on a clean vertical-static touch.
- `ProcessedView`'s outer `ScrollView` keeps scrolling because each expanded `List` has `.scrollDisabled(true)` and an explicit fixed height.
- Near-future window is exactly 10 days inclusive of end-of-day-of-day-10, as specified. Items beyond 10 days are intentionally hidden.
- The `STATE.md` "Last updated" line bumped to 2026-04-27 and a full update-log entry added at the top of the log.
