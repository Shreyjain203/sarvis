# process-now-fix — output

Fixed the Process button so it actually does work: capture is now raw-only, the classifier is the only path into `processed/<type>.json`, and errors are surfaced in the toast.

## Commit

- `667de59` — Fix Process: capture writes raw-only, classifier distributes, errors visible

## Files changed

| File | Change |
|---|---|
| `Sarvis/Models/TodoStore.swift` | `capture(...)` now persists only a `RawEntry`; returns an in-memory `TodoItem` (id == raw id) without writing it anywhere. Removed `InputProcessor.process` + `add(processed.item)` + the TRANSITIONAL DUAL-WRITE comment block. |
| `Sarvis/Models/RawEntry.swift` | Added optional `notificationID`. Custom `init(from:)` keeps back-compat with old `raw/<uuid>.json` files. |
| `Sarvis/Services/Storage/RawStore.swift` | New `setNotificationID(for:_:)` writes a scheduled notification's id onto the raw and rewrites the file. |
| `Sarvis/Screens/InputView.swift` | `save()` now writes `notificationID` back onto the raw via `RawStore.shared.setNotificationID(...)` instead of `store.update(...)`. `runClassifier()` toast surfaces `error.localizedDescription` (truncated to 140 chars). On a zero-item happy path, surfaces `ClassifierService.shared.lastLLMError` if set. |
| `Sarvis/Screens/TodayView.swift` | Rewritten. Reads unprocessed raws from `RawStore.shared` via `@ObservedObject`, sorts desc by `capturedAt`, groups by start-of-day. New `RawEntryRow` view (importance dot, suggestedType chip, sensitive lock, captured time). Swipe-delete cancels notification then removes raw. Empty state copy updated. Removed legacy `TodoRow` (was only used here). |
| `Sarvis/Services/LLM/LLMService.swift` | Added `ask(systemPrompt:prompt:options:)` overload so callers can override `LLMOptions` without mutating the shared options struct. |
| `Sarvis/Services/LLM/ClassifierService.swift` | Distribution loop always materialises a `TodoItem` per classified raw (no early return on `suggestedType`). User pick wins for type; LLM drives `text` / `importance` / `dueAt` / `isSensitive`; raw's `notificationID` is carried forward. Mark raw processed only after the TodoItem write. Calls LLM with `maxTokens = max(default, 4096)`. `parseResponse` now slices between first `{` and last `}` to survive preamble / postamble. Exposes `lastLLMError` for the UI. |
| `STATE.md` | Storage paragraph rewritten (capture is raw-only). Classifier paragraph updated (resolution rule, maxTokens, parseResponse). Public API table corrected. Dual-write duplicate caveat documented. New 2026-04-26 update-log entry. |

## Build

`xcodebuild -project Sarvis.xcodeproj -scheme Sarvis -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED**.

Only pre-existing `@frozen` warnings on `Sarvis/Models/AnyCodableValue.swift`. No new diagnostics.

## Behaviour notes

- After this lands, capture writes a single `raw/<uuid>.json` file. Nothing appears in `TodoStore.items` until Process is clicked.
- The Entries tab shows ONLY unprocessed raws. Processed items live in the matching Library tab.
- Tapping Process on raws that were already dual-written before this change will produce duplicates in the Library tab. The user has been told (in `STATE.md`) to manually delete duplicates.
- Errors from the classifier (missing API key, HTTP failure, JSON-parse error) now appear in the toast verbatim instead of "Process failed".
- `CaptureScreenDynamic.swift` was intentionally NOT modified (per plan's "don't touch" directive). Its `var saved = store.capture(...)` followed by `saved.notificationID = nid; store.update(saved)` remains compilable but is now a no-op for the patched `TodoItem` (the raw never gets the notificationID via that path). If `CaptureScreenDynamic` is ever re-activated in `RootView`, switch its `save()` to `RawStore.shared.setNotificationID(for: saved.id, nid)` for parity with `InputView`.
