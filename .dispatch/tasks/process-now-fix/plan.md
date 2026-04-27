# Process-now fix — architecture flip + visible errors

User intent: clicking Process should pick up unprocessed raw entries, send them to Anthropic for classification, write the structured items into the right `processed/<type>.json` buckets, and mark the raws processed. Visible result: items disappear from Entries (which should show only unprocessed raws) and appear in the matching Library tab. Errors should surface to the toast.

Today's gaps (from prior diagnosis):

1. Capture **dual-writes** to BOTH `raw/` AND `processed/<type>.json` (`TodoStore.capture` at `Sarvis/Models/TodoStore.swift:99`). Entries reads `TodoStore.items` (the processed bucket), so items appear in Entries AND the matching Library tab BEFORE Process is ever clicked. Nothing visible moves on click.
2. Classifier short-circuits when `suggestedType != nil` — only flips the raw flag, never writes a TodoItem (it relied on the dual-write). After we remove the dual-write, this branch must always create a TodoItem.
3. `LLMOptions.maxTokens = 1024` (`Sarvis/Services/LLM/LLMProvider.swift:19`) likely truncates batch JSON on multi-entry responses.
4. `parseResponse` (`ClassifierService.swift:206`) only strips ```` ``` ```` fences — fails on any other preamble/suffix.
5. UI swallows the real error: `runClassifier` toasts `"Process failed"` on every throw, hiding API-key / model / JSON / network issues.

---

- [x] **Stop dual-write in `TodoStore.capture(...)`.** Remove the `InputProcessor.process(raw)` + `add(processed.item)` lines and the "TRANSITIONAL DUAL-WRITE" doc block. Keep the `capture(...)` signature and return type stable so existing callers compile. Return a synthesized in-memory `TodoItem` (not persisted to TodoStore) for the caller to use locally — e.g., for notification scheduling.
- [x] **Move notificationID storage onto `RawEntry`.** Add `var notificationID: String?` to `Sarvis/Models/RawEntry.swift` (Codable-friendly default-decoded as nil for old files). Update `InputView.save()` so that after scheduling a notification, the ID is written back into the raw entry via a new `RawStore.shared.update(...)` method (or equivalent — add a `setNotificationID(for: UUID, _ id: String)` if cleaner). The classifier should carry that notificationID forward into the resulting `TodoItem` when it materialises one.
- [x] **Rewire Entries (`Sarvis/Screens/TodayView.swift`) to read unprocessed raws.** Use `@StateObject` or `@ObservedObject` on `RawStore.shared`. Source list = `RawStore.shared.entries.filter { !$0.processed }`, sorted by `capturedAt` desc, grouped by `Calendar.startOfDay(for: capturedAt)`. Reuse the existing date-header logic (Today / Yesterday / weekday / MMM d / MMM d, yyyy). Tweak the empty-state copy (e.g. "Nothing waiting to be processed.").
- [x] **Build a `RawEntryRow` view** that renders a `RawEntry`. Show: serif-body text, suggestedType chip if present, importance dot, sensitive lock if applicable, capturedAt time in the meta row. Swipe-trailing → Delete via `RawStore.shared.delete(entry.id)` (and cancel any scheduled notification via the new `notificationID` field). No isDone toggle — these aren't TodoItems yet. Place it in `TodayView.swift` or a sibling file as you prefer; keep the visual idiom consistent with the existing `TodoRow`.
- [x] **Update `ClassifierService.classifyUnprocessed`:**
  - For EVERY classified item, always create a `TodoItem` and call `TodoStore.shared.add(item)`. Drop the early-return branch on `suggestedType != nil`.
  - Type resolution: if the raw had `suggestedType`, prefer it over the LLM's type (respect user choice). The LLM's cleaned `text`, `importance`, `dueAt`, and `isSensitive` still apply.
  - Carry `notificationID` from the raw onto the resulting `TodoItem`.
  - Mark each raw processed only after the corresponding TodoItem write succeeds.
- [x] **Bump classifier maxTokens.** Either add an `ask(systemPrompt:prompt:options:)` overload on `LLMService` that lets ClassifierService pass `LLMOptions(maxTokens: 4096)`, or have ClassifierService construct its own options and call `provider.send(...)` directly. Pick whichever keeps `LLMService` clean.
- [x] **Improve `parseResponse`** in ClassifierService: locate the FIRST `{` and the LAST `}` in the cleaned string and slice between them. This survives any preamble/postamble (e.g. "Here's the JSON:" or trailing prose).
- [x] **Surface real errors in `InputView.runClassifier`:** on any throw, set the toast to the actual `error.localizedDescription` (truncate to ~140 chars). On success with `report.itemsAdded == 0`, check `llm.lastError` (or the equivalent on the classifier's internal LLMService) and surface that if set. Keep the existing item-count toast for happy-path runs.
- [x] **Update `STATE.md`:** rewrite the Storage / "raw → processed pipeline" paragraph (capture is now raw-only; classifier is the only path into processed buckets). Note one-time data caveat: pre-existing items in `processed/<type>.json` from prior dual-writes remain; clicking Process on raws that were already dual-written will produce a duplicate in the matching Library tab — acceptable, user can manually delete dupes. Append a 2026-04-26 update-log entry summarising the flip + error visibility.
- [x] **Build sanity-check** the modified Swift files. — `xcodebuild -scheme Sarvis -destination 'generic/platform=iOS Simulator' build` → BUILD SUCCEEDED. Only pre-existing `@frozen` warnings on `AnyCodableValue.swift`.
- [x] **One clean commit, no push.** — `667de59` Subject: something like "Fix Process: capture writes raw-only, classifier distributes, errors visible".
- [x] **Write summary to `.dispatch/tasks/process-now-fix/output.md`.**

---

**Context:**

- Reference files (read these before editing):
  - `Sarvis/Models/TodoStore.swift` — `capture(...)` at L99 (dual-write source).
  - `Sarvis/Services/Storage/RawStore.swift` — has `unprocessed()`, `markProcessed`, `delete`. `@MainActor`, `@Published var entries`, already SwiftUI-reactive.
  - `Sarvis/Models/RawEntry.swift` — extend with `notificationID`.
  - `Sarvis/Screens/TodayView.swift` — Entries view; flip its data source.
  - `Sarvis/Screens/InputView.swift` — `save()` (notification path) + `runClassifier()` (toast).
  - `Sarvis/Services/LLM/ClassifierService.swift` — distribute logic at L107, parseResponse at L206.
  - `Sarvis/Services/LLM/LLMService.swift` + `Sarvis/Services/LLM/LLMProvider.swift` — for maxTokens override.
  - `Sarvis/Services/Storage/InputProcessor.swift` — currently a no-op middleware; if nothing else calls it after the flip, leave it as a stub (don't delete unless clean).

- Existing data caveat: users (the user himself) may already have `processed/<type>.json` items from prior dual-writes AND `raw/<uuid>.json` entries with `processed=false`. Don't delete the existing processed items. Don't auto-mark raws as processed at startup. Mention the duplicate-on-process possibility in STATE.md.

- Operating constraints:
  - Don't push (`git push`) — commit only. User pushes on milestones.
  - Don't touch `Sarvis/Screens/CaptureScreenDynamic.swift` (parallel dynamic version, not active in RootView).
  - Don't change the InputView toolbar layout (Process icon left of Settings) — only fix the underlying behavior + the toast text.
  - Pre-existing SourceKit "Cannot find X in scope" diagnostics are project-indexing flake the user already flagged. Ignore.

- Decision-making: questions written to `ipc/<NNN>.question` won't be picked up mid-run (no monitor). Make best-effort decisions yourself. Only block with `[!]` on genuinely unresolvable issues.
