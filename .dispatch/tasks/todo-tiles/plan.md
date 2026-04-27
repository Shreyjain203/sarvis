# Todo tab redesign: tiles + swipe-done + completed history + edit

User outcome: replace the current flat Todo list under Library → Todo with a tiled timeline view. Today gets a big tile. Tomorrow + Near-future get smaller tiles below. Each tile expands to show its tasks. Tasks swipe-left to mark done (NOT deleted), are tap-to-edit, and a Completed history view (sorted by completion time desc) lets the user revert any of them. Every Todo item must carry a date component (specific date/time OR a window like "within 7 days").

---

## 1. Data model + classifier

- [x] **Add `completedAt: Date?` to `TodoItem`** (`Sarvis/Models/TodoItem.swift`). Codable-friendly default = nil. Update `TodoStore.toggleDone(_:)` so flipping `isDone` also writes/clears `completedAt = Date()` accordingly. Existing files decode cleanly because `Codable` synthesised init handles the missing key as nil. — done
- [x] **Make Todo items always carry a date.** Two parts: — done
  - **Classifier prompt** (`prompts/capture_classify.md` AND its bundled mirror at `Sarvis/Resources/Prompts/capture_classify.md`): for any item the LLM tags `type: "task"`, REQUIRE a `dueAt` ISO-8601 timestamp. If the user said "in 7 days" / "next month" / "soon" / etc., infer a concrete `dueAt` (e.g., `today + 7 days at 09:00`, end-of-month, today + 1 day for "soon"). Never return a task with `dueAt: null`. Add a clear sentence to the prompt to that effect, with 2–3 examples ("clean garage" → today+7, "buy milk before friday" → next Friday 09:00, "doctor appointment may 14 3pm" → exact ISO timestamp).
  - **Classifier safety net** (`Sarvis/Services/LLM/ClassifierService.swift` around L213): if `resolvedType == .task && dueDate == nil`, set `dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())` so the bucketing never sees a task without a date. Log a debug-distribution-entry note like `"task without dueAt → defaulted to +7d"` so it's visible in the debug viewer.

## 2. Todo tiles UI

- [x] **Replace the flat Todo section in `Sarvis/Screens/ProcessedView.swift` with a tile layout.** Pull the new view into its own file — `Sarvis/Screens/TodoSectionView.swift` — to keep ProcessedView lean. ProcessedView's `todoSection` becomes one line: `TodoSectionView()`. Inject `@EnvironmentObject var todoStore: TodoStore`. — done
- [x] **Tile layout:** vertical stack inside the existing ScrollView. — done
  - Top: a single LARGE tile, full width, ~220pt tall (or use a GeometryReader to take ~50% of screen height — pick whichever reads cleaner; 220pt fixed is fine). Title "Today", subtitle = today's date, count badge = `todayCount`.
  - Below: an HStack with two equal-width tiles, ~140pt tall each. Left = "Tomorrow" (count badge). Right = "Near future" (count badge, subtitle "Next 10 days").
  - All three tiles use the existing `themedCard` idiom + Theme tokens for consistency.
  - Each tile is a Button → tapping toggles an `expanded: Set<TileKey>` state (where `TileKey = .today, .tomorrow, .nearFuture`). When expanded, show the tile's task list inline below the tile (smooth `.easeInOut` animation). Collapsed shows just the count.
  - Pre-condition: tiles always show task counts even when collapsed. Use a small pill on the tile's top-right with the integer.
- [x] **Bucketing logic** (lives in `TodoSectionView` as private computed properties on a helper struct or just inline funcs): — done
  - `todayItems`: `.task` items with `!isDone` and `Calendar.current.isDateInToday(dueAt)`.
  - `tomorrowItems`: `.task` items with `!isDone` and `Calendar.current.isDateInTomorrow(dueAt)`.
  - `nearFutureItems`: `.task` items with `!isDone` and `dueAt > end-of-tomorrow` AND `dueAt <= today + 10 days (end of day)`. (Items beyond 10d are intentionally hidden — they'll surface as the date approaches.)
  - Sort each bucket by `dueAt` asc, then `importance` desc as tiebreaker.

## 3. Per-task row inside expanded tile

- [x] **New row view: `TodoTaskRow`** (in `TodoSectionView.swift` or a sibling). Renders a single `TodoItem` with the `ReadOnlyTodoRow` visual idiom (importance dot + serif text + meta row with due time). On tap → opens the edit sheet (item below). NOT a Button-wrapping-a-row; use `.contentShape(Rectangle())` + `.onTapGesture` so swipe gesture isn't swallowed. — done
- [x] **Swipe-left to mark done.** Use SwiftUI's `.swipeActions(edge: .trailing)` — that REQUIRES the rows to live in a `List`, not a VStack. Refactor each tile's expanded body to use a `List` styled to look stylesheet-compatible: `.listStyle(.plain)`, `.scrollDisabled(true)` (so the outer ScrollView keeps scrolling), `.listRowBackground(Color.clear)`, `.listRowSeparator(.hidden)`, and an explicit `.frame(height: rowHeight * count)` so the List doesn't try to be infinite-tall. The trailing swipe button: red, label "Done", icon `checkmark.circle.fill`. Action: `todoStore.toggleDone(item.id)` (which now also stamps `completedAt`). — done
- [x] **Edit sheet: `TodoEditSheet`.** Tapping a task row presents this sheet (`@State var editing: TodoItem?` + `.sheet(item: $editing)`). Sheet UI: — done
  - Multi-line text editor pre-filled with `item.text`.
  - Importance chips (reuse `ImportanceChip` from InputView — extract it to its own file `Sarvis/UI/Elements/ImportanceChipRow.swift` if it's still private; otherwise duplicate the styling inline).
  - Sensitive toggle (LockPill or just a plain `Toggle`).
  - Date picker bound to `dueAt` (mandatory for tasks per the new rule — no toggle to clear).
  - Save button → `todoStore.update(updatedItem)`. Cancel → dismiss.
  - Keep visuals consistent with `InputView`'s capture flow.

## 4. Completed history viewer

- [x] **Add a small icon in the top-right of `TodoSectionView`,** below ProcessedView's section-picker chip row. Use SF symbol `clock.arrow.circlepath` (or `archivebox`) and `Theme.Palette.muted`. Tap → NavigationLink to `CompletedTodosView`. — done
- [x] **`CompletedTodosView.swift`** — new file, presented in a NavigationStack push (or sheet — pick push so the user can swipe-back). Lists every `.task` item with `isDone == true`, sorted by `completedAt` desc (fallback to `createdAt` desc if `completedAt` is nil for legacy items). Each row uses the same row visual; swipe-trailing → "Revert" action, calls `todoStore.toggleDone(item.id)` (which flips back to undone and clears `completedAt`). Empty state: "Nothing completed yet." — done (CompletedTodosView lives in TodoSectionView.swift to keep navigation locality)

## 5. Build + commit

- [x] **Build sanity-check.** `xcodebuild -project Sarvis.xcodeproj -scheme Sarvis -destination 'generic/platform=iOS Simulator' build` should succeed. Pre-existing `@frozen` warnings on `AnyCodableValue.swift` are fine. SourceKit "Cannot find X in scope" diagnostics on already-flagged files are project-indexing flake — ignore. — done (BUILD SUCCEEDED, 2026-04-27)
- [x] **One commit, no push.** Suggested subject: "Todo tab: tiled timeline + swipe-done + completed history + edit sheet". Update `STATE.md` with a 2026-04-27 entry summarising the tile layout, the always-have-a-date rule, the completed view, and the edit sheet. — done (commit 982b62d on worktree-agent-a39601ac, no push)
- [x] **Write summary to `.dispatch/tasks/todo-tiles/output.md`.** — done

---

**Context:**

- Reference files (read first):
  - `Sarvis/Screens/ProcessedView.swift` — current Todo section is in `todoSection` (recently added). Replace with `TodoSectionView()`.
  - `Sarvis/Models/TodoItem.swift` — add `completedAt`.
  - `Sarvis/Models/TodoStore.swift` — `toggleDone(_:)` writes the timestamp; `update(_:)` already exists.
  - `Sarvis/UI/Elements/Display/TodoListRow/TodoListRowView.swift` — `ReadOnlyTodoRow` is the row visual; OK to wrap or copy.
  - `Sarvis/Services/LLM/ClassifierService.swift` — defaults block goes around line 213.
  - `prompts/capture_classify.md` and the bundled mirror `Sarvis/Resources/Prompts/capture_classify.md` — both must be updated.
  - `Sarvis/Screens/InputView.swift` — `ImportanceChip` and `LockPill` references; treat as shared UI to mirror in the edit sheet.
  - `STATE.md` — for the update-log entry.
- Constraints:
  - Don't push commits — `git push` is reserved for milestones.
  - Don't touch news/MorningJob code — paused.
  - Don't touch `Sarvis/Screens/CaptureScreenDynamic.swift` (parallel dynamic version, not active).
  - Pre-existing SourceKit "Cannot find X in scope" warnings are noise — ignore unless an actual `xcodebuild` step fails.
  - The tap-to-edit flow on tasks must NOT block swipe gestures. If `.onTapGesture` swallows swipes inside a List, prefer no tap gesture and use `.listRowBackground` + a transparent `NavigationLink` overlay or sheet trigger that doesn't compete with `.swipeActions`. Test mentally before committing to the approach.
  - "Near future" window is fixed at 10 days inclusive of dueAt at end-of-day-of-day-10. Items beyond 10 days are intentionally not shown (yet).
  - Items without `completedAt` (legacy) should still show in the completed view if `isDone == true` — sort by `createdAt` as fallback.
- Decision-making: questions written to `ipc/<NNN>.question` won't be picked up mid-run (no monitor). Make best-effort decisions. Only block with `[!]` on genuinely unresolvable issues.
