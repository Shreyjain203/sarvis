# Rename: ReminderApp → Sarvis — Output

## Files Renamed

| Old Path | New Path |
|---|---|
| `ReminderApp/` (folder) | `Sarvis/` |
| `Sarvis/App/ReminderAppApp.swift` | `Sarvis/App/SarvisApp.swift` |
| `ReminderWidget/` (folder) | `SarvisWidget/` |
| `ReminderApp.xcodeproj` | Deleted (stale); replaced by `Sarvis.xcodeproj` (regenerated) |

## Files Modified

| File | What Changed |
|---|---|
| `Sarvis/App/SarvisApp.swift` | `struct ReminderAppApp` → `struct SarvisApp` |
| `Sarvis/Services/LLM/PromptLibrary.swift` | Doc comments: `ReminderApp/Resources/Prompts/` → `Sarvis/Resources/Prompts/` (×2) |
| `SarvisWidget/QuickCaptureView.swift` | URL scheme `reminderapp://capture` → `sarvis://capture` |
| `project.yml` | Project name, bundleIdPrefix, target names, source/resource/info paths, bundle IDs, URL scheme, CFBundleDisplayName, widget dependency |
| `setup.sh` | `open ReminderApp.xcodeproj` → `open Sarvis.xcodeproj` |
| `tools/sync-prompts.sh` | DST path `ReminderApp/Resources/Prompts` → `Sarvis/Resources/Prompts` |

## Total `ReminderApp` References Replaced

- `project.yml`: 10 occurrences (project name, bundleIdPrefix, 2× target names, 2× source/resource/info paths, bundle IDs, URL scheme, display name, widget dep)
- `Sarvis/App/SarvisApp.swift`: 1 (struct name)
- `Sarvis/Services/LLM/PromptLibrary.swift`: 2 (doc comments)
- `SarvisWidget/QuickCaptureView.swift`: 1 (`reminderapp://` → `sarvis://`)
- `setup.sh`: 1 (xcodeproj filename)
- `tools/sync-prompts.sh`: 1 (DST path)

**Total: ~16 references replaced**

## UI Strings Intentionally Left As-Is

- `QuickCaptureView.swift` line 31: `Label("Reminder", ...)` — this is widget UI copy labelling the widget's purpose, not the app name. The plan says only "About Reminder"-style app-name labels should change. Left as-is pending the widget worker's content pass.
- `QuickCaptureView.swift` line 54: `Label("Quick Capture", ...)` — generic UI copy, not an app-name reference.

## Verification

- `xcodegen generate`: exit 0, `Sarvis.xcodeproj` created at project root.
- `swiftc -parse`: all 17 Swift files under `Sarvis/` parse cleanly.
- Final grep for `ReminderApp`/`reminderapp` (excluding `.dispatch/` and `Readme.md`): **zero survivors**.
