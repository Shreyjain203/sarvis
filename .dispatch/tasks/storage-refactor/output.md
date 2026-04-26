# Storage Refactor — Implementation Summary

## Per-type file layout in the Documents directory

Each `InputType` case maps to a dedicated JSON file in the app's Documents directory:

| Type        | File             | Schema                  |
|-------------|------------------|-------------------------|
| `.task`     | `tasks.json`     | `[TodoItem]` JSON array |
| `.note`     | `notes.json`     | `[TodoItem]` JSON array |
| `.idea`     | `ideas.json`     | `[TodoItem]` JSON array |
| `.sensitive`| `sensitive.json` | `[TodoItem]` JSON array |
| `.other`    | `other.json`     | `[TodoItem]` JSON array |

Each file holds **only items of that type**. Files are written atomically (`.atomic` write option).

`TodoItem` schema (JSON keys match Swift property names via synthesised `Codable`):
```json
{
  "id": "<UUID>",
  "text": "string",
  "importance": 0-3,
  "isSensitive": bool,
  "type": "task|note|idea|sensitive|other",
  "createdAt": "<ISO8601>",
  "dueAt": "<ISO8601> | null",
  "isDone": bool,
  "notificationID": "string | null"
}
```

The `type` field defaults to `"task"` if missing (Codable synthesised default), so old data without the key round-trips safely.

---

## `InputProcessor.process(_:)` extension point

**File:** `ReminderApp/Services/Storage/InputProcessor.swift`

`InputProcessor.process(_ raw: RawInput) -> ProcessedInput` is currently a no-op pass-through that:
1. Resolves the final `InputType` (explicit > sensitive-flag > default `.task`).
2. Constructs a `TodoItem` from the raw fields.
3. Returns it wrapped in `ProcessedInput`.

The comment `// TODO: future classification` marks the spot to add:
- **ML / rule-based classification** — automatically bucket free-form text into task/note/idea.
- **PII redaction** — strip or mask sensitive personal data before persistence.
- **Auto-sensitive detection** — flag items containing patterns like credit card numbers or passwords.
- **Tag enrichment** — attach derived tags or categories.
- **Normalisation** — trim, capitalise, or expand abbreviations before saving.

Any change here is automatically applied to every path that calls `store.capture(...)`, including the widget.

---

## `TodoStore.capture(...)` widget API contract

```swift
@discardableResult
func capture(
    text: String,
    type: InputType,
    importance: Importance = .medium,
    isSensitive: Bool = false,
    dueAt: Date? = nil
) -> TodoItem
```

The widget worker should call:
```swift
TodoStore.shared.capture(text: userInput, type: .note)
```

- `type: .note` — use whatever type is appropriate for the capture surface.
- All other parameters have safe defaults.
- The call is synchronous and returns the persisted `TodoItem`.
- The item is immediately visible via `store.items` (published) and in `TodoStore.shared.items(in:)`.
- Notification scheduling is **not** done inside `capture` — the widget should omit `dueAt` or schedule notifications separately if needed.

---

## Migration behaviour on first launch with existing `todos.json`

On `TodoStore.init()`, before loading the typed files, `migrateIfNeeded()` runs:

1. Checks for `Documents/todos.json`.
2. If found, decodes it as `[TodoItem]`.
3. Infers each item's type: `isSensitive == true` → `.sensitive`, otherwise `.task` (the only two types that existed before this refactor).
4. Writes each type bucket to its new file atomically.
5. Deletes `todos.json` only after all new files are successfully written.
6. On any error, logs to console and leaves `todos.json` intact (safe fallback — next launch retries).

After migration the typed files are loaded normally via `loadAll()`.
