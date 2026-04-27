# ui-updates-wave-2 — output

## What shipped

### Entries tab (TodayView.swift)
- Dropped `todayItems` / importance-grouped layout entirely.
- Now reads `TodoStore.shared.items` (all types), sorted by `createdAt` descending.
- Grouped into day sections using `Calendar.current.startOfDay(for:)` as the bucket key.
- Section headers: "Today", "Yesterday", weekday name (within 7 days), "MMM d" (same year), "MMM d, yyyy" (older).
- Header title changed from "Today" → "Entries"; meta line: "Everything you've captured."
- `TodoRow` reused as-is for all item types (sensitive items inline, no separate forked group).
- Added `.scrollDismissesKeyboard(.immediately)` on the ScrollView.

### Tab bar (RootView.swift)
- Tab label: "Today" → "Entries".
- Tab icon: `leaf` → `tray`.
- Internal `Tab` enum case left as `.today` (no external impact).

### Library tab (ProcessedView.swift)
- Removed `ProcessedSection.today` case (label, symbol, body dispatch, and all three helpers: `todaySection`, `sensitiveSectionBlock`, `importanceGroupBlock`).
- Default `selectedSection` changed from `.today` to `.notes`.

### STATE.md
- New "UI rules" section added above "Update log" — documents theme tokens, screen root pattern, navigation conventions, button style, animation curves, haptics, tab-bar clearance, card/chip radii, keyboard dismiss, and dynamic-UI registration.
- 2026-04-26 update log entry appended summarizing this wave.

## Commits
1. `c5fbf90` — Capture page rework (InputView.swift): tap-to-dismiss, AI assist card removed, Process now in toolbar.
2. `8fad13e` — Entries rebuild + Library trim + STATE.md updates.

## No push — milestone push deferred to user.
