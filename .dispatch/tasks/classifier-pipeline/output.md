# Classifier Pipeline — Completion Summary

## Prompt contract (`prompts/capture_classify.md`)

**Input variables** (injected into the system prompt):
- `{{entries}}` — JSON array of raw entry dicts: `id`, `text`, `importance`, `isSensitive`, `suggestedType?`, `dueAt?`, `capturedAt`
- `{{profile}}` — JSON object: `preferences` (string dict), `traits` (string array)
- `{{today}}` — ISO-8601 current datetime for relative date resolution

**Output JSON shape** (no prose, no fences):
```json
{
  "items": [
    { "rawId": "<uuid>", "type": "task|note|idea|shopping|diary|quote|suggestion|sensitive|other",
      "text": "<cleaned text>", "importance": "low|medium|high",
      "dueAt": "<ISO-8601 | null>", "isSensitive": false }
  ],
  "notifications": [
    { "title": "...", "body": "...", "fireAt": "<ISO-8601>" }
  ],
  "profileDeltas": { "preferences": {}, "traits": [] }
}
```

## ClassifierService API (`Sarvis/Services/LLM/ClassifierService.swift`)

```swift
@MainActor final class ClassifierService: ObservableObject {
    static let shared: ClassifierService
    @Published private(set) var isRunning: Bool

    func classifyUnprocessed() async throws -> ClassifierReport
}

struct ClassifierReport {
    let itemsAdded: Int
    let rawsMarked: Int
    let notificationsScheduled: Int
}
```

Errors: `ClassifierError.alreadyRunning`, `.llmFailed(String)`, `.badJSON(String)` — all surface as throws.

## Dual-write reconciliation rule

When the classifier runs:
- **Entry has `suggestedType != nil`**: user picked a type at capture time; the item was already written to `processed/<type>.json` by the dual-write shim in `TodoStore.capture(...)`. Classifier just calls `RawStore.shared.markProcessed(id)` — trusts the user's pick.
- **Entry has `suggestedType == nil`**: no user pick; classifier creates a `TodoItem` from the LLM-classified output, calls `TodoStore.shared.add(item)`, then marks raw processed. The raw entry is only marked processed after `add` succeeds (atomic per-entry).

LLM failures throw before any writes or mark-processed calls occur.

## Notification scheduling from LLM output

`ClassifierService` iterates `response.notifications[]`. For each entry where `fireAt` parses to a future `Date`, it calls the new `NotificationService.shared.schedule(title:body:at:)` overload (added in `NotificationService.swift`). This creates a `UNTimeIntervalNotificationTrigger` directly without needing a `TodoItem`. The existing `schedule(_ todo:at:)` path is untouched.

## Profile merge semantics (`ProfileStore.merge(_:)`)

`ProfileStore.merge(_ partial: [String: Any])` accepts:
- `"preferences"`: `[String: String]` — new keys added, existing keys overwritten (no removals)
- `"traits"`: `[String]` — appended to existing list, duplicates skipped

After merging, `updatedAt` is stamped and the file is written atomically.

## UI wiring

- `CaptureScreenDynamic`: `capture.aiAssist` action now calls `ClassifierService.shared.classifyUnprocessed()`. Shows `ToastCenter` with count on success, "Process failed" on error. Old per-capture clean-up is preserved under `capture.cleanupCurrent`.
- `InputView`: new "Process now" themed pill button (matching existing `aiAssistCard` idiom) placed above Save, wired to same `ClassifierService.shared.classifyUnprocessed()` call.

## Known limits

- **LLM JSON parse failures**: if the model returns malformed JSON (e.g., markdown-wrapped), the classifier throws `ClassifierError.badJSON` and no raws are marked processed. No retry — caller may try again.
- **Partial classification**: if the LLM omits some `rawId`s from `items[]`, those raws remain unprocessed on this run and will be included in the next classifier invocation.
- **Retry policy**: none. Failed runs are surfaced to the user via `ToastCenter.shared.show("Process failed")`. The user can tap the button again.
- **Date resolution**: relative dates ("tomorrow", "Friday") rely on the LLM resolving them against `{{today}}`. No local date parsing fallback.
- **Concurrency**: `isRunning` guard prevents re-entrancy; a second tap while running is silently ignored.
