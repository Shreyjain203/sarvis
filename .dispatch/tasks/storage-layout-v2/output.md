# Storage Layout v2 — Output Summary

## New Directory Layout

```
Documents/
  raw/
    <uuid>.json                   # one RawEntry per file (written by RawStore)
  processed/
    tasks.json                    # array of TodoItem
    notes.json
    ideas.json
    sensitive.json
    other.json
    diary.json
    suggestions.json
    shopping.json
    quotes.json
    profile.json                  # singleton Profile struct
    plans/
      <YYYY-MM-DD>.json           # daily artifact (written by DailyArtifactStore)
    news/
      <YYYY-MM-DD>.json           # daily artifact (written by DailyArtifactStore)
```

## New InputType Cases

Four new cases added to `Sarvis/Models/InputType.swift`:

| Case          | label        | symbol          | fileName          |
|---------------|--------------|-----------------|-------------------|
| `.diary`      | "Diary"      | `book.closed`   | `diary.json`      |
| `.suggestion` | "Suggestion" | `lightbulb`     | `suggestions.json`|
| `.shopping`   | "Shopping"   | `cart`          | `shopping.json`   |
| `.quote`      | "Quote"      | `quote.bubble`  | `quotes.json`     |

`.profile`, `.plan`, `.news` are NOT InputType cases — they are system/derived artifacts.

## RawStore API (`Sarvis/Services/Storage/RawStore.swift`)

`@MainActor final class RawStore: ObservableObject` — singleton via `RawStore.shared`.

- `@Published private(set) var entries: [RawEntry]` — all loaded entries, sorted by `capturedAt`.
- `func add(_ entry: RawEntry)` — atomic write to `raw/<uuid>.json`, appends to array.
- `func unprocessed() -> [RawEntry]` — filters `processed == false`.
- `func markProcessed(_ id: UUID)` — sets `processed = true`, stamps `processedAt`, rewrites file.
- `func delete(_ id: UUID)` — removes file and array entry.
- `init()` (private) — creates `raw/` directory if absent, loads all `.json` files from it.

## ProfileStore API (`Sarvis/Services/Storage/ProfileStore.swift`)

`@MainActor final class ProfileStore: ObservableObject` — singleton via `ProfileStore.shared`.

Profile stub:
```swift
struct Profile: Codable {
    var preferences: [String: String]
    var traits: [String]
    var updatedAt: Date
}
```

- `@Published private(set) var profile: Profile` — current profile (`.empty` if file absent).
- `func save(_ updated: Profile)` — updates in-memory and atomically writes `processed/profile.json`.
- Returns an empty `Profile` on first access if the file doesn't exist.

## DailyArtifactStore API (`Sarvis/Services/Storage/DailyArtifactStore.swift`)

`final class DailyArtifactStore` — singleton via `DailyArtifactStore.shared`. Not `@MainActor` (generic I/O helper).

- `func read<T: Codable>(folder: String, date: Date) -> T?` — reads `processed/<folder>/<YYYY-MM-DD>.json`.
- `func write<T: Codable>(_ value: T, folder: String, date: Date)` — atomically writes `processed/<folder>/<YYYY-MM-DD>.json`; creates the subfolder if absent.
- Used by the `news-fetcher` worker (for `news/`) and future `plans` worker.

## Dual-Write Transitional Behavior in `capture(...)`

`TodoStore.capture(text:type:importance:isSensitive:dueAt:)` now:

1. Creates a `RawEntry` with `processed: false`, dispatches `RawStore.shared.add(entry)` on MainActor.
2. **Also** runs the existing `InputProcessor.process(_:)` path and calls `add(_:)` to write to `processed/<type>.json` as before.

This keeps `TodayView`, `InputView`, and `CaptureScreenDynamic` working without any changes. A `// TODO: classifier-pipeline` comment marks the exact lines to remove when Wave 2 flips to raw-only capture.

## Migration Plan

`TodoStore.init()` runs two migration steps before `loadAll()`:

**Step 1 — Flat → processed/ move** (storage-layout-v1 → v2):
For each `InputType`, if `Documents/<type>.json` exists and `Documents/processed/<type>.json` does not, the file is moved atomically. Failures are logged and originals are left intact.

**Step 2 — Legacy todos.json** (pre-v1):
If `Documents/todos.json` exists, items are decoded, sensitive items are re-typed as `.sensitive`, then distributed into per-type files under `processed/`. The legacy file is deleted only after all new files succeed. Failures are logged and the original is left intact.

Both steps are idempotent and safe to run on any app launch.

## UI Fix

`Sarvis/Screens/InputView.swift`:
- `enableNotification` default changed from `true` → `false`.
- `dueAt` default changed from `Date().addingTimeInterval(3600)` → `Date()`.
- Both are reset to these defaults after a successful save.
- Result: the date/time row is hidden on first load; a date is only assigned when the user explicitly taps the bell pill.

`Sarvis/Screens/CaptureScreenDynamic.swift`:
- Already had `"optional": .bool(true)` on the `CalendarPicker` element spec.
- `dueAt` resolves to `nil` when absent from `ScreenState` — no change needed.
