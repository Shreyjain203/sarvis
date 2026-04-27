# Phase 1 — Foundation

> **Tag:** `v0.1.0` · **Shipped:** 2026-04-27 · **Status:** ✅ complete (frozen)
>
> This document is the retrospective plan for Phase 1. It describes what was built, why, and how. For the current state of the codebase (which moves past this tag), read [`STATE.md`](../STATE.md).

## Goal

Stand up a working iOS app that proves the core pipeline:

```
free-form text capture → LLM classification → typed Library buckets → notifications
```

Phase 1 is foundation, not polish. The bar is: a user can write anything, hit Process, and see the result land in the right tab with a sensible due date and importance.

## Outcomes — what shipped

### App scaffold + navigation

- `SarvisApp` entry point, `RootView` with three tabs: **Capture** (write input), **Entries** (list of unprocessed raws), **Library** (processed buckets).
- Tab bar uses `matchedGeometryEffect` for the selected indicator.
- Settings sheet from a top-right toolbar slot.
- Horizontal swipe paging between Capture / Entries / Library.

### Capture pipeline (raw → processed)

Two-stage data model, deliberately separated:

- **Raw store** (`Documents/raw/<uuid>.json`) — every capture writes a `RawEntry` here. Append-only. Source of truth for input.
- **Processed store** (`Documents/processed/<type>.json`) — typed buckets per `InputType` (`task`, `note`, `idea`, `sensitive`, `other`, `diary`, `suggestion`, `shopping`, `quote`).

`TodoStore.capture(text:type:importance:isSensitive:dueAt:)` writes only to raw and returns a synthesized in-memory `TodoItem` whose id matches the raw's id (so the caller can schedule a notification immediately and write the notification id back via `RawStore.setNotificationID`). Items materialize into processed buckets only after the user taps **Process**.

This split lets us:
- Re-run classification at will (raw is preserved)
- Show users their unprocessed inbox (Entries tab)
- Avoid double-writes that masked classifier bugs

### Classifier

- `ClassifierService.shared.classifyUnprocessed()` — reads unprocessed raws, calls Anthropic via `LLMService` with `claude-opus-4-7`, parses JSON by slicing between the first `{` and last `}` (survives preamble/postamble), materializes a `TodoItem` per raw via `TodoStore.add(...)`, marks each raw processed only after a successful write, schedules notifications, merges profile deltas.
- Reconciliation rule: if the user picked a type at capture (`suggestedType != nil`), that wins. Otherwise the LLM's `type` is used. The LLM's cleaned `text`, `importance`, `dueAt`, and `isSensitive` always apply.
- Safety net: if a `.task` lands without `dueAt`, default to today + 7 days at 09:00 (logged in the debug viewer).
- Always-have-a-date rule for tasks codified in `prompts/capture_classify.md` with fuzzy-phrase guidance.
- `maxTokens` bumped to 4096 to avoid truncation on dense batches.
- Every run captured to `ClassifierDebugRecord` and surfaced in Settings → Debug → "View last classifier run."

### Library (`ProcessedView`)

Section chip picker across the top: **Todo, Notes, Shopping, Diary, Ideas, Suggestions, Quotes, News, Profile.** Each section reads from the appropriate store and renders with the shared visual idiom.

#### Todo tiled timeline (`TodoSectionView`)

Replaces a flat list. Four equal-width tiles stacked vertically:

| Tile | Bucket |
|---|---|
| Today | `.task && !isDone && Calendar.isDateInToday(dueAt)` |
| Tomorrow | `.task && !isDone && Calendar.isDateInTomorrow(dueAt)` |
| Near Future | `.task && !isDone && dueAt > end-of-tomorrow && dueAt ≤ end-of-day(today + 10)` |
| Everything Else | `.task && !isDone && (dueAt > end-of-day(today + 10) || dueAt == nil)` |

- Today expanded by default; others collapsed.
- Each tile contains its task list **inside** the card (header + hairline divider + List).
- Tasks: tap → edit sheet (text / importance / sensitive / mandatory due date). Trailing swipe → mark done (stamps `completedAt`).
- `clock.arrow.circlepath` icon in the section header → push to `CompletedTodosView`. Sorted by `completedAt` desc with `createdAt` desc fallback for legacy items. Trailing swipe → revert.

### Notifications

- `NotificationService.schedule(title:body:at:)` — generic time-based notification.
- Notification IDs roundtripped: scheduled at capture, written back onto the raw, carried forward onto the processed `TodoItem`.
- Two action buttons: **Done** / **Snooze**.

### Background jobs

- **`MorningJob`** (`com.shrey.sarvis.morning`) — `BGAppRefreshTask` registered in `SarvisApp.init()`, scheduled for next 7 AM. Calls `NewsService.refreshToday()` → LLM summarizes via `prompts/news_summary.md` → stored at `processed/news/<date>.json` → notification "Today's briefing" with summary baked in.
- **`QuoteJob`** — schedules two `UNCalendarNotificationTrigger` pings per day (9:30 AM + a deterministic 14–18h slot keyed to day-of-year). Bodies baked at schedule time; torn down + re-scheduled on every app launch.
- Quote source: `Sarvis/Resources/Quotes/seed.json` (35 seed quotes) + `Documents/processed/quotes.json` (user-captured). `QuoteService` merges + dedupes.

### Theme + design system

- `Sarvis/UI/Theme.swift` — design tokens: `Spacing`, `Radius`, `Typography` (serif for headings + body, system for meta), `Palette` (warm neutrals + an importance-keyed dot palette).
- `Theme.LayeredBackground` — every screen root.
- `.themedCard(padding:cornerRadius:)` modifier — single source of truth for card visuals.
- `Haptics.soft / light / success` — consistent vibration vocabulary.
- `ToastCenter.shared.show(...)` — global transient banner.

### Dynamic UI composer (foundation laid)

- `ScreenDefinition` + `ElementSpec` — screens described as data, not hardcoded.
- `ElementRegistry` (singleton) — `register(name, factory)` to plug in elements.
- `ScreenState` — observable bag of binding values.
- `DynamicScreen` — renders any `ScreenDefinition` by looking up factories.
- Built-in elements (`Sarvis/UI/Elements/`):
  - **Input:** `TextInput`, `CalendarPicker`, `TypeChip`, `ImportancePicker`, `ToggleRow`, `ShoppingItem` (4-level urgency).
  - **Display:** `SummaryCard`, `ActionButton`, `TodoListRow`, `NotesListRow`, `ShoppingListRow`, `DiaryEntry`, `QuoteCard`, `NewsHeadline`.
- `CaptureScreenDynamic` — parallel dynamic version of the capture screen (legacy `InputView` still active in `RootView`).

### Other

- API key in Keychain (`KeychainService` wrapper).
- Anthropic integration via `LLMProvider` / `AnthropicProvider` / `LLMService`.
- News fetch: `GNewsProvider` against the GNews free tier (Phase 2 replaces this with RSS).
- App icon: monkey image, full iPhone+iPad+marketing PNG set generated via `sips`.
- Widget code present (`SarvisWidget/`) but disabled in `project.yml` due to a device codesign issue. Phase 2 re-enables and trims it.

## Key decisions

1. **Raw and processed are separate stores.** Forces every classification path through a single materializer; lets us re-run safely.
2. **`suggestedType` overrides the LLM** — if the user explicitly tagged something at capture time, we trust them. The LLM only gets to override `text`, `importance`, `dueAt`, `isSensitive`.
3. **Tasks must always carry a date.** Either the user gave one, the LLM inferred one, or the safety net defaults to today + 7d. Eliminates the "items beyond all buckets" failure mode.
4. **JSON parsing slices between the first `{` and last `}`.** Anthropic responses occasionally include preamble/postamble despite `system` directives — slicing is more forgiving than strict parsing without giving up structure.
5. **Dynamic UI composer is in but not on the critical path.** It's there for future LLM-described screens; existing screens still use hand-built SwiftUI.
6. **No third-party deps.** Anthropic + Apple frameworks only. Keeps codesign clean and supply chain small.

## What was deliberately deferred

These were scoped *out* of Phase 1 and roadmapped to later phases:

- **Email integration (Gmail)** — Phase 2.
- **Durable news source (RSS)** — Phase 2 (current `GNewsProvider` works but rate-limited).
- **Custom notification UI** — Phase 2.
- **Widget re-enable** — Phase 2.
- **Plans daily artifact writer** — `DailyArtifactStore` exists for storage; the LLM writer that produces `processed/plans/<date>.json` is not yet built.
- **Personalized quote LLM call** — `prompts/quote_pick.md` is a placeholder; quotes are picked by `QuoteService` deterministically for now.
- **Notification service extension** — would let quote/morning bodies be computed at fire time instead of bake time.
- **Screen Time / Location / reward-gated shopping unlock** — long-tail roadmap.

## Dispatched workers (history)

Phase 1 was built across multiple dispatched-worker waves. Plan files + outputs live in `.dispatch/tasks/<task-id>/`.

| Worker | Wave | Status |
|---|---|---|
| ui-polish | early | ✅ |
| prompts-folder | 1 | ✅ |
| toast-and-keyboard | 1 | ✅ |
| storage-refactor | 1 | ✅ |
| quick-capture-widget | early | partial → finished by `finish-widget` |
| rename-to-sarvis | 1 | ✅ |
| rewrite-readme | 1 | ✅ |
| dynamic-ui-composer | 2 | ✅ |
| finish-widget | 2 | ✅ |
| storage-layout-v2 | 1 | ✅ |
| news-fetcher | 1 | ✅ |
| classifier-pipeline | 2 | ✅ |
| shopping-urgency-element | 2 | ✅ |
| morning-and-quotes-jobs | 2 | ✅ |
| processed-viewer-screen | 3 | ✅ |
| process-now-fix | 3 | ✅ |
| ui-updates-wave-2 | 3 | ✅ |
| debug-viewer-and-icon | 3 | ✅ |
| todo-tiles | 3 | ✅ |

## Reproducing the v0.1.0 state

```bash
git fetch --tags
git checkout v0.1.0
xcodegen generate
open Sarvis.xcodeproj
```

Paste an Anthropic API key in Settings on first launch.
