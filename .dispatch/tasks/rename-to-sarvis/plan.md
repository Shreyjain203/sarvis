# Rename: ReminderApp → Sarvis

Sweep-rename the entire project. This must complete cleanly before any other code worker runs, so do this surgically and verify at the end.

- [x] **Rename source folder:** `ReminderApp/` → `Sarvis/` (use `git mv` if repo is git-tracked, else plain `mv`). — Done via `mv` (no git repo).
- [x] **Rename app entry file:** `Sarvis/App/ReminderAppApp.swift` → `Sarvis/App/SarvisApp.swift`. Inside, renamed `@main struct ReminderAppApp` → `@main struct SarvisApp`.
- [x] **Rename widget folder if present:** `ReminderWidget/` → `SarvisWidget/`. — Existed; renamed.
- [x] **Rename entitlements file if present:** `ReminderApp.entitlements` → `Sarvis.entitlements` — No entitlements file found; skipped.
- [x] **Update `project.yml`:** — All target names, bundle IDs, source/resource paths, Info.plist path, CFBundleDisplayName, URL scheme, widget dependency updated.
- [x] **Sweep all `.swift` files for `ReminderApp` references** — Updated `SarvisApp.swift` (struct name) and `PromptLibrary.swift` (doc comments). UI copy strings left intentionally (see output.md).
- [x] **Sweep all `.swift` files for `reminderapp://` URL scheme** → `sarvis://`. — Updated `SarvisWidget/QuickCaptureView.swift`.
- [x] **Update `setup.sh`** — Updated xcodeproj filename reference.
- [x] **Update `tools/sync-prompts.sh`** — Updated DST path to `Sarvis/Resources/Prompts`.
- [x] **Do NOT modify `.dispatch/tasks/*/plan.md` or `output.md`** — Respected (only this plan and the new output.md written).
- [x] **Do NOT modify `Readme.md`** — Not touched.
- [x] **Run `xcodegen generate`** — Exit 0; `Sarvis.xcodeproj` created.
- [x] **Run `swift -frontend -parse`** — All 17 Swift files under `Sarvis/` parse cleanly (OK).
- [x] **Final grep check** — Zero survivors in code. Stale `ReminderApp.xcodeproj` removed. See output.md for intentional UI string exceptions.
- [x] Write a summary to `.dispatch/tasks/rename-to-sarvis/output.md` — Done.

**Constraints:**
- iOS 17+. Don't change behavior, only names.
- Don't touch `.dispatch/tasks/` historical files.
- Don't touch `Readme.md` (parallel worker owns it).
- Atomic — if anything fails midway, mark the failed item `[!]` and stop so the user can decide whether to roll back.
- The widget files (if present from the earlier partial run) may be incomplete — rename them but don't try to fix their content. A later worker will finish the widget.
