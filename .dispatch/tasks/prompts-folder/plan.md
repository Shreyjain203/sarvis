# Prompts folder + bundle

Centralize every LLM prompt the app uses (or might use later) in editable markdown files at a top-level `prompts/` folder, bundle them as app resources, and load them at runtime via a small `PromptLibrary` helper. The user can edit prompt files later without touching Swift.

- [x] Create top-level `prompts/` directory with these markdown files. Each file MUST start with a YAML-style header listing `purpose:`, `when_used:`, `variables:` (named `{{...}}` placeholders), separated from the body by a `---` line. Files:
  - `prompts/basic_app.md` — overall app system prompt / persona (placeholder body for the user to fill).
  - `prompts/capture_cleanup.md` — the system prompt currently hardcoded in `InputView.runLLM` ("Rewrite the user's note as one short, clear todo line. Keep their intent. No preamble.") — move it here verbatim with a proper header.
  - `prompts/daily_update.md` — placeholder body for future daily-summary prompts.
  - `prompts/classify_input.md` — placeholder for an "input classifier" prompt that picks which file/category a captured note belongs to.
  - `prompts/sensitive_detect.md` — placeholder for detecting whether captured text is sensitive.
- [x] Mirror those five files into `ReminderApp/Resources/Prompts/` (this is the bundled copy). Add a tiny `tools/sync-prompts.sh` that copies `prompts/*.md` → `ReminderApp/Resources/Prompts/` so the user has one shell command to keep them in sync. Make it executable.
- [x] Update `project.yml` to include `ReminderApp/Resources/Prompts` as a resource folder reference (XcodeGen `resources:` block) so the markdown files end up in the app bundle. Re-run `xcodegen generate`.
- [x] Add `ReminderApp/Services/LLM/PromptLibrary.swift`:
  - `enum PromptLibrary` with `static func body(for name: String, fallback: String) -> String`.
  - Loads `<name>.md` from the main bundle, strips the YAML-style header (everything from the first `---` line up to and including the next `---` line), returns the trimmed body.
  - Returns `fallback` if the file isn't found or is empty after stripping.
- [x] Update `InputView.swift` `runLLM()` to load the system prompt via `PromptLibrary.body(for: "capture_cleanup", fallback: <current inline string>)` instead of hardcoding it.
- [x] Run `swift -frontend -parse` on `PromptLibrary.swift` and the modified `InputView.swift`. Both parsed without errors.
- [x] Write a summary to `.dispatch/tasks/prompts-folder/output.md` listing each prompt file's purpose, the `PromptLibrary` API, the sync workflow, and how the user adds a new prompt later.

**Constraints:**
- Don't break the existing "Clean up with Claude" flow — same behavior, same default prompt.
- Don't change `LLMService` or `LLMProvider` APIs.
- Keep the YAML-header parser dead-simple — split on `---` lines, no third-party YAML lib.
- `InputView.swift` may be edited concurrently by another worker (`storage-refactor`); your edit to `runLLM()` is small and localized — limit your changes there to that method only.
