# UI updates wave 2 — Today tab rebuild + Library cleanup + UI rules

- [x] Rebuild `Sarvis/Screens/TodayView.swift`: drop the today-only filter, show ALL items from `TodoStore.shared.items` sorted by `createdAt` descending, grouped into day sections with headers ("Today", "Yesterday", weekday name for the last 7 days, "MMM d" for current year, "MMM d, yyyy" for older). Keep the existing `TodoRow` visuals. The header title should change from "Today" to **"Entries"**, with the meta line updated to something neutral (e.g., "Everything you've captured.").
- [x] Update `Sarvis/App/RootView.swift`: rename the tab label from "Today" → "Entries". Changed icon to `tray`. Internal Tab enum case left as `.today`.
- [x] Edit `Sarvis/Screens/ProcessedView.swift`: removed `.today` case from `ProcessedSection` enum (label, symbol, body dispatch, `todaySection` + `sensitiveSectionBlock` + `importanceGroupBlock` helpers). Default `selectedSection` changed to `.notes`.
- [x] Add a new top-level **"UI rules"** section to `STATE.md` (above the "Update log" section).
- [x] Append a `2026-04-26` entry to STATE.md's update log summarizing this wave's changes.
- [x] Build sanity-check: reviewed all three modified Swift files — no new unresolved references introduced. Pre-existing SourceKit noise on InputView.swift not touched.
- [x] Commit locally in two clean commits:
  1. `c5fbf90` — Capture page rework (InputView.swift)
  2. `8fad13e` — Entries rebuild + Library trim + STATE.md updates
- [x] Write summary of changes to `.dispatch/tasks/ui-updates-wave-2/output.md`.

**Context:**

- Outcome: finish the UI cleanup wave the user described. Capture page edits are already partly done (InputView.swift was rewritten in this session — tap-to-dismiss via `.scrollDismissesKeyboard(.immediately)` + outer `.onTapGesture`, AI assist card removed, Process-now relocated to top-trailing toolbar next to Settings). What's left: Entries tab, Library trim, UI rules doc, and committing.
- Read first: `STATE.md` at the project root for the architecture/conventions snapshot.
- Reference files: `Sarvis/Screens/TodayView.swift`, `Sarvis/App/RootView.swift`, `Sarvis/Screens/ProcessedView.swift`, `Sarvis/UI/Theme.swift` (for design tokens), `Sarvis/Models/TodoStore.swift` (for the `items` array and sort fields), `Sarvis/Screens/InputView.swift` (already edited — reference for top-toolbar pattern).
- The Entries view should show items across ALL types (tasks, notes, shopping, diary, ideas, etc.) — not just one bucket. Use `TodoStore.shared.items` and sort by `createdAt` desc. Group by `Calendar.current.startOfDay(for:)` of `createdAt`. Keep `TodoRow` for rendering — it already handles done-toggle for tasks, and it gracefully shows non-task types too.
- For sensitive items in the Entries view, you can keep the red-tinted card treatment inline with the rest of the day's section (don't fork into a separate sensitive group anymore — it's now a date-partitioned timeline).
- UI rules section in STATE.md should cover, briefly:
  - Theme tokens are the source of truth: `Theme.Spacing`, `Theme.Radius`, `Theme.Typography`, `Theme.Palette`.
  - Every screen roots in `ZStack { Theme.LayeredBackground(); content }`.
  - Use `NavigationStack` with `.navigationBarTitleDisplayMode(.inline)`. Primary actions go in `ToolbarItem(placement: .topBarTrailing)` (or `ToolbarItemGroup` when multiple). Toolbar icons use `.font(.system(size: 16, weight: .regular))` and `Theme.Palette.muted`.
  - Buttons use `.buttonStyle(.plain)` with hand-rolled backgrounds (RoundedRectangle / Capsule with `.ultraThinMaterial` + hairline stroke).
  - Animations: `.spring(response: 0.35, dampingFraction: 0.85)` for chip selection, `.easeInOut(duration: 0.2)` for fades.
  - Haptics: `Haptics.soft()` on selection, `Haptics.light()` on tap, `Haptics.success()` on save.
  - Bottom padding `Color.clear.frame(height: 96)` reserves space for the floating tab bar.
  - Cards: `.themedCard(padding:cornerRadius:)` modifier; chips use `Theme.Radius.chip`, cards `Theme.Radius.card`, hero surfaces `Theme.Radius.hero`.
  - Keyboard dismiss: `.scrollDismissesKeyboard(.immediately)` on ScrollViews + `.onTapGesture` on the screen ZStack to release `@FocusState`. Keep `.dismissKeyboardToolbar()` as the fallback.
  - Dynamic-UI screens go through `ElementRegistry` + `DynamicScreen` + `ScreenDefinition`; new element types must be registered.
- Constraints:
  - The existing `TodoRow` uses `@EnvironmentObject var store: TodoStore`. RootView already injects `TodoStore.shared`, so don't change the injection.
  - Don't touch `CaptureScreenDynamic.swift` (parallel dynamic version, not active in RootView).
  - Don't push commits — only `git commit`. The user has a strict "push on milestones only" rule.
  - The user said the backend is "messed up" — pre-existing SourceKit warnings on InputView.swift and elsewhere are not your concern. Just don't introduce new structural issues in the files you edit.
