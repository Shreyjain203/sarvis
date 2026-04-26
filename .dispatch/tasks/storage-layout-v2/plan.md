# Storage layout v2: raw/ + processed/ split

Reorganize the Documents directory into the canonical pipeline: every capture lands in `raw/` first, gets classified later. Adds new `InputType` cases for the broader Sarvis taxonomy. Also includes the small "empty default datetime" UI fix on the capture screens (folded in here because the same files are touched).

**Final Documents layout (target):**
```
Documents/
  raw/
    <uuid>.json                   # one RawEntry per file
  processed/
    tasks.json                    # array of TodoItem (current shape)
    notes.json
    ideas.json
    sensitive.json
    other.json
    diary.json
    suggestions.json
    quotes.json
    shopping.json
    profile.json                  # singleton (Profile)
    plans/
      <YYYY-MM-DD>.json           # daily artifact
    news/
      <YYYY-MM-DD>.json           # daily artifact
```

**New InputType cases to add:** `.diary`, `.suggestion`, `.shopping`, `.quote`. (We're NOT adding `.profile`, `.plan`, `.news` as InputType cases — those are derived/system artifacts, not user-entered categories. They get their own stores below.)

- [x] **Update `Sarvis/Models/InputType.swift`:** add `.diary`, `.suggestion`, `.shopping`, `.quote`. Set `label`, `symbol` (SF Symbol), `fileName` for each:
  - `.diary` → "Diary", `book.closed`, `diary.json`
  - `.suggestion` → "Suggestion", `lightbulb`, `suggestions.json`
  - `.shopping` → "Shopping", `cart`, `shopping.json`
  - `.quote` → "Quote", `quote.bubble`, `quotes.json`
- [x] **Add `Sarvis/Models/RawEntry.swift`:**
  ```swift
  struct RawEntry: Identifiable, Codable {
      let id: UUID
      var text: String
      var importance: Importance
      var isSensitive: Bool
      var suggestedType: InputType?      // user-picked type at capture, may be overridden by classifier
      var dueAt: Date?
      var capturedAt: Date
      var processed: Bool
      var processedAt: Date?
  }
  ```
- [x] **Add `Sarvis/Services/Storage/RawStore.swift`** (`@MainActor final class RawStore: ObservableObject` singleton):
  - Persists each `RawEntry` as `Documents/raw/<uuid>.json` (atomic write).
  - `func add(_ entry: RawEntry)` — writes the file + appends to in-memory `@Published var entries: [RawEntry]`.
  - `func unprocessed() -> [RawEntry]` — filter on `processed == false`.
  - `func markProcessed(_ id: UUID)` — sets the flag, rewrites the file, updates the array.
  - `func delete(_ id: UUID)` — removes the file + the array entry.
  - `init()` loads everything from `Documents/raw/` on first access.
- [x] **Refactor `Sarvis/Models/TodoStore.swift` paths:**
  - All per-type files now live under `Documents/processed/<type>.json` instead of `Documents/<type>.json`.
  - Update `fileURL(for:)` accordingly (create `Documents/processed/` if missing).
  - **Migration:** on init, if `Documents/<type>.json` exists for any `InputType` and the new `Documents/processed/<type>.json` doesn't, move the file. Try/catch — leave originals on failure. Also keep the existing `todos.json` legacy migration intact (it now writes to `Documents/processed/<type>.json` too).
  - Items array shape unchanged.
- [x] **Change `TodoStore.capture(...)` to route through raw:**
  - The existing signature stays: `capture(text:type:importance:isSensitive:dueAt:) -> TodoItem`.
  - Internally, build a `RawEntry` with `processed: false`, write to `RawStore`, **also** still create the `TodoItem` and add it to the appropriate processed file as before (so existing screens keep working). This way we ship raw plumbing without breaking immediate-write behavior. The classifier worker (Wave 2) will switch this so capture writes raw-only and classification distributes — but for THIS worker, write to BOTH so the build stays green.
  - Add a TODO comment marking the transitional dual-write and pointing at `classifier-pipeline` task.
- [x] **Add `Sarvis/Services/Storage/ProfileStore.swift`** — singleton holding a `Profile` struct (stub: `struct Profile: Codable { var preferences: [String: String]; var traits: [String]; var updatedAt: Date }`). Reads/writes `Documents/processed/profile.json` atomically. Returns an empty profile if file doesn't exist.
- [x] **Add `Sarvis/Services/Storage/DailyArtifactStore.swift`** — generic helper for date-keyed JSON: `func read<T: Codable>(folder: String, date: Date) -> T?`, `func write<T: Codable>(_ value: T, folder: String, date: Date)`. Uses `processed/<folder>/<YYYY-MM-DD>.json`. Used later by news + plans.
- [x] **Update capture screens — empty default datetime:**
  - `Sarvis/Screens/InputView.swift`: `enableNotification` default changed to `false`, `dueAt` default changed to `Date()`. Both reset to these defaults after save. Date row is now hidden on first load.
  - `Sarvis/Screens/CaptureScreenDynamic.swift`: already had `"optional": .bool(true)` on CalendarPicker; `dueAt` resolves to `nil` when absent from ScreenState — no change needed.
- [x] **Verification:** `swift -frontend -parse` on all new + modified files returned exit 0. `xcodegen generate` returned exit 0 and wrote `Sarvis.xcodeproj`.
- [x] **Migration smoke check (read-only):** `createProcessedDirectoryIfNeeded()` is called before `migrateIfNeeded()` and `loadAll()`, so the directory always exists before any read/write. Step 1 (flat→processed move) guards on `fileExists` before moving and catches errors. Step 2 (todos.json) only deletes the legacy file after all new writes succeed. All paths safe.
- [x] Write a summary to `.dispatch/tasks/storage-layout-v2/output.md` covering: new directory layout (with a tree), new InputType cases, RawStore API, ProfileStore API, DailyArtifactStore API, the dual-write transitional behavior in `capture(...)`, and the migration plan from old paths.

**Constraints:**
- iOS 17+. Atomic writes everywhere.
- Don't break existing screens — the dual-write strategy keeps `TodayView` and `InputView` reading from processed files exactly as today.
- Don't touch the dynamic UI composer infra (`Sarvis/UI/Composer/`, `Sarvis/UI/Elements/`) except for the empty-default-datetime fix in `CaptureScreenDynamic.swift`.
- Don't touch `SarvisWidget/`.
- Don't touch `Sarvis/Services/News/` (parallel `news-fetcher` worker owns it).
- iOS Documents directory is the only persistence root — no shared App Groups in this worker.
