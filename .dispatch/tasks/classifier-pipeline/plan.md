# Classifier pipeline (raw → processed via LLM)

Build the "ask LLM" engine: read unprocessed raw entries, call Claude with a structuring prompt, distribute outputs to `processed/<type>.json`, mark raw as processed. This is the front-page button that converts messy → organized.

**Important — dual-write transitional behavior:** `storage-layout-v2` left `TodoStore.capture(...)` writing to BOTH raw AND processed (so existing screens keep working). Keep that dual-write **for now**. The classifier's job is to *refine* — read UNPROCESSED raw entries, ask the LLM to classify + clean up, then either:
- **(recommended for v1)** skip raw entries where the user already picked a `suggestedType` (those are already in the right processed bucket — just mark them processed),
- OR for entries with no suggested type / vague text, replace the dual-written preview with the LLM's cleaned version.

- [x] **Add prompt file `prompts/capture_classify.md`** with the YAML header pattern. Body: instruct Claude to read a JSON array of raw entries `{{entries}}` and a JSON profile snippet `{{profile}}`, return a JSON object:
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
    "profileDeltas": { "preferences": {...}, "traits": [...] }
  }
  ```
  Add a clear "Output JSON only, no prose" instruction. Run `tools/sync-prompts.sh` to mirror to `Sarvis/Resources/Prompts/`. — Created `prompts/capture_classify.md`; synced 7 prompts to `Sarvis/Resources/Prompts/`.
- [x] **Add `Sarvis/Services/LLM/ClassifierService.swift`** — `@MainActor final class ClassifierService`:
  - `func classifyUnprocessed() async throws -> ClassifierReport` — reads `RawStore.shared.unprocessed()`, builds the prompt via `PromptLibrary.body(for: "capture_classify", fallback: ...)`, calls `LLMService` with the existing API surface, decodes the JSON response.
  - For each item in response:
    - If `rawId` matches an unprocessed entry that had `suggestedType == nil` (vague/no user pick): create a `TodoItem` and call `TodoStore.shared.add(...)`. Then mark raw processed via `RawStore.shared.markProcessed(rawId)`.
    - If `suggestedType != nil`: just mark raw processed (already dual-written; trust the user's pick over the LLM).
  - Schedule each `notifications[*]` via `NotificationService.schedule(...)` — synthesize a `TodoItem`-shaped struct or use a separate notification helper if `NotificationService` only takes `TodoItem`.
  - Apply `profileDeltas` via `ProfileStore.shared.merge(_:)` — add a `merge` method on `ProfileStore` that takes a partial dict and merges into the persistent `Profile`.
  - `struct ClassifierReport { let itemsAdded: Int; let rawsMarked: Int; let notificationsScheduled: Int }` — return for UI feedback.
  - Errors surface as throws; LLM failures should NOT mark raws processed. — Created `Sarvis/Services/LLM/ClassifierService.swift`; all constraints met.
- [x] **Wire the front-page button** in `Sarvis/Screens/CaptureScreenDynamic.swift`:
  - The screen already has a `"capture.aiAssist"` action via the `ActionButton` element. Repurpose its label to "Process with LLM" and bind it to call `ClassifierService.shared.classifyUnprocessed()`. On success: `ToastCenter.shared.show("Processed N items")`. On failure: `ToastCenter.shared.show("Process failed")`.
  - Keep the existing per-capture cleanup action (`runLLM` style) under a different action name if it still exists; the headline button is now the classifier.
  - In `Sarvis/Screens/InputView.swift` (legacy capture screen): add a small toolbar button or a row above Save labeled "Process now" wired to the same `ClassifierService.shared.classifyUnprocessed()` call. Match existing visual idiom — themed pill button. — Wired `capture.aiAssist` → classifier; old cleanup kept as `capture.cleanupCurrent`. Added "Process now" pill in `InputView` above Save.
- [x] **Add `func merge(_ partial: [String: Any])` on `ProfileStore`** — minimal: parse known keys (`preferences` dict, `traits` array), update the Profile struct, write atomically. Don't overengineer — string-keyed updates are fine. — Added `merge(_:)` to `ProfileStore`; merges preferences (upsert) and traits (dedup append).
- [x] **Notification scheduling helper:** if `NotificationService` only accepts `TodoItem`, add a thin `schedule(title:body:at:)` overload that creates an internal lightweight UNMutableNotificationContent + UNCalendarNotificationTrigger directly. Keep `TodoItem` path intact. — Added `schedule(title:body:at:)` overload to `NotificationService`.
- [x] **Verification:** `swift -frontend -parse` on every new + modified Swift file. `xcodegen generate` exit 0. — All 5 files parsed clean; xcodegen exited 0.
- [x] Write a summary to `.dispatch/tasks/classifier-pipeline/output.md` covering: the prompt contract (input + output JSON shape), `ClassifierService` API, the dual-write reconciliation rule (suggestedType wins), how notifications get scheduled from LLM output, profile merge semantics, and known limits (LLM JSON parse failures, partial classification, retry policy — none yet). — Written to `.dispatch/tasks/classifier-pipeline/output.md`.

**Constraints:**
- iOS 17+. No third-party deps.
- Don't touch `Sarvis/Services/News/`, `Sarvis/UI/Elements/Input/ShoppingItem/`, or `Sarvis/Services/Jobs/` (parallel workers own those).
- Don't add a new tab or screen — this is a service + button wiring.
- LLM failures must be safe: never mark raw processed unless the corresponding processed item was actually written. Atomic per-entry.
- Keep prompts editable — don't hardcode the prompt body in Swift, always go through `PromptLibrary`.
