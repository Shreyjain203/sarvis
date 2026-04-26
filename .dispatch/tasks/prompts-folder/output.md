# Prompts Folder — Completion Summary

## Prompt files and their purposes

| File | Purpose |
|------|---------|
| `prompts/basic_app.md` | Overall app persona / base system context injected into all AI calls |
| `prompts/capture_cleanup.md` | Cleans up a raw captured note into one short actionable todo line — used by `InputView.runLLM()` |
| `prompts/daily_update.md` | Future: generates a brief daily summary of pending reminders |
| `prompts/classify_input.md` | Future: classifies a note into a user-defined category for auto-routing |
| `prompts/sensitive_detect.md` | Future: detects whether a note contains sensitive/private content |

Each file starts with a YAML-style header (`purpose:`, `when_used:`, `variables:`), then a `---` separator, then the prompt body. Only the body is returned at runtime.

## PromptLibrary API

```swift
// ReminderApp/Services/LLM/PromptLibrary.swift
enum PromptLibrary {
    static func body(for name: String, fallback: String) -> String
}
```

- `name` — the base filename (no `.md`), e.g. `"capture_cleanup"`.
- Looks up `<name>.md` in the app bundle, strips the header block (everything up to and including the first `---` line), returns the trimmed body.
- Returns `fallback` if the file is missing, unreadable, or empty after stripping — so the existing behavior is always preserved.

## Sync workflow

Edit prompt text in `prompts/<name>.md` (repo root — human-readable, version-controlled), then run:

```sh
./tools/sync-prompts.sh
```

This copies all `prompts/*.md` → `ReminderApp/Resources/Prompts/`. Re-build the app to pick up the changes.

## How to add a new prompt

1. Create `prompts/<name>.md` with the required header:
   ```
   purpose: …
   when_used: …
   variables:
     - {{placeholder}}: description
   ---
   Your prompt body here.
   ```
2. Run `./tools/sync-prompts.sh`.
3. In Swift, call:
   ```swift
   let prompt = PromptLibrary.body(for: "<name>", fallback: "…fallback text…")
   ```
4. Optionally add the name to this summary table above.

No changes to `LLMService` or `LLMProvider` are needed.
