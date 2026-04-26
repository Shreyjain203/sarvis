# Typed storage + middleware + InputView updates

Replace single-file persistence with one file per input type, run all captures through a no-op middleware function (placeholder for future logic), and update `InputView` / `TodayView`. Also apply the toast + keyboard-dismiss modifiers (defined by the parallel `toast-and-keyboard` worker) to `InputView`.

- [x] Add `ReminderApp/Models/InputType.swift`:
  - `enum InputType: String, Codable, CaseIterable, Identifiable { case task, note, idea, sensitive, other }`.
  - `var id: String { rawValue }`, `label`, `symbol` (SF Symbol), `fileName` (e.g. `task` → `tasks.json`, `note` → `notes.json`, `idea` → `ideas.json`, `sensitive` → `sensitive.json`, `other` → `other.json`).
- [x] Update `ReminderApp/Models/TodoItem.swift` — add `var type: InputType = .task` (default keeps current behavior; existing decoded JSON without the field will use the default via `Codable`'s synthesized init).
- [x] Add `ReminderApp/Services/Storage/InputProcessor.swift`:
  - `struct RawInput { var text: String; var importance: Importance; var isSensitive: Bool; var type: InputType?; var dueAt: Date? }`
  - `struct ProcessedInput { var item: TodoItem }`
  - `enum InputProcessor { static func process(_ raw: RawInput) -> ProcessedInput { ... } }` — currently a no-op pass-through that constructs a `TodoItem` from the raw fields. If `raw.type == nil`, default to `.sensitive` when `isSensitive == true`, else `.task`. Leave a clear `// TODO: future classification` comment marking this as the extension point.
- [x] Refactor `ReminderApp/Models/TodoStore.swift`:
  - Persist items to per-type files in the Documents directory using each `InputType.fileName`. Each file holds a `[TodoItem]` array (only items of that type).
  - Internally keep a flattened `items: [TodoItem]` so existing accessors (`todayItems`, `sensitiveItems`, `todayItems(importance:)`) still work.
  - `add(_:)` saves to the file matching the item's type.
  - `update(_:)` and `delete(_:)` rewrite the appropriate type file. Handle the case where `update` changes an item's `type` (remove from old file, add to new).
  - Add `func items(in type: InputType) -> [TodoItem]`.
  - **Migration:** on init, if `Documents/todos.json` exists, decode it, infer each item's type (`.sensitive` if `isSensitive`, else `.task`), write into the new typed files, then delete the old `todos.json`. Guard with a try/catch — on failure, leave the old file in place and log.
  - Add `@discardableResult func capture(text: String, type: InputType, importance: Importance, isSensitive: Bool, dueAt: Date?) -> TodoItem` that runs `InputProcessor.process(...)`, calls `add(...)`, returns the item. This is the public API the widget worker will call.
- [x] Update `ReminderApp/Screens/InputView.swift`:
  - Add an `InputType` chip row beneath the importance row, in the same `ImportanceChip` visual idiom (small material chips). Default to `.task`. Used a horizontal `ScrollView` to accommodate 5 chips without crowding. Used a separate `inputTypeNS` namespace to avoid conflicting with the existing `importanceNS` `matchedGeometryEffect`.
  - Replace the direct `store.add(item)` call in `save()` with `store.capture(text:type:importance:isSensitive:dueAt:)`.
  - Applied `.dismissKeyboardToolbar()` to the `ScrollView` (wraps the full form area).
  - Replaced the inline "Saved." flash with `ToastCenter.shared.show("Saved")`.
  - Removed `savedFlash` state and the `if savedFlash { … }` conditional view from `statusFooter`.
  - Left the AI assist call site (`systemPrompt:` argument) untouched — already updated by the prompts-folder worker.
- [x] Update `ReminderApp/Screens/TodayView.swift` if needed: confirmed no change needed. `TodoStore.todayItems`, `sensitiveItems`, and `todayItems(importance:)` all operate on the flattened `items` array which is populated identically. Zero regressions.
- [x] Run `swift -frontend -parse` on every modified Swift file. All five files (InputType, TodoItem, InputProcessor, TodoStore, InputView) parsed without errors.
- [x] Write a summary to `.dispatch/tasks/storage-refactor/output.md` describing:
  - The per-type file layout in the Documents directory (one JSON per type, schema).
  - The `InputProcessor.process(_:)` extension point and what to add there later (classification, redaction, etc.).
  - The `TodoStore.capture(...)` widget API contract (what to call from the widget worker).
  - The migration behavior on first launch with existing `todos.json`.

**External API contracts:**
- The widget worker (later) will call `TodoStore.shared.capture(text:type:importance:isSensitive:dueAt:)` with `type: .note`, default importance, `isSensitive: false`, `dueAt: nil`.
- The toast-and-keyboard worker has implemented `ToastCenter.shared.show(_:)` and `.dismissKeyboardToolbar()`. If those symbols don't compile yet when this worker runs, that's expected — the build goes red until both workers finish, then green.

**Constraints:**
- Don't break notification scheduling — `NotificationService.schedule(_:at:)` still gets a `TodoItem` and works as-is.
- iOS 17+.
- Atomic file writes (`.atomic` write option) for every typed file.
- The chip row UI must respect the existing Theme spacing scale and not break the `matchedGeometryEffect` namespace already used for importance.
