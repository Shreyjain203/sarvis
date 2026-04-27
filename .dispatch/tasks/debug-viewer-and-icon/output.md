# debug-viewer-and-icon — output

Single commit: `11dac2e` "Add classifier debug viewer + new app icon (monkey)" — not pushed.

## 1. Classifier debug viewer

- `Sarvis/Services/LLM/ClassifierService.swift`
  - New `ClassifierDebugRecord` struct (timestamp, input raws snapshot, filled
    system + user prompt, raw LLM response, pretty-printed parsed JSON,
    per-item distribution log, itemsAdded count, error description).
  - Nested `ClassifierDebugRecord.DistributionEntry` captures per-item
    routing: rawSnippet → resolvedType → "added" or "skipped: <reason>".
  - `ClassifierService` now publishes `@Published private(set) var lastRun:
    ClassifierDebugRecord?`. `classifyUnprocessed()` populates it on every
    exit path — LLM-nil, parse failure, success, plus any later throw —
    via a local `recordDebug(error:)` closure that snapshots the
    accumulators (rawResponseForDebug, parsedPrettyForDebug,
    distributionForDebug, itemsAddedForDebug).
  - Distribution log also includes raws the LLM didn't return ("skipped:
    not returned by LLM") and items whose rawId didn't match this batch
    ("skipped: rawId not in this batch").
  - In-memory only — only the most recent run is kept.

- `Sarvis/Screens/ClassifierDebugView.swift` (new)
  - Sections: header (timestamp + summary chips), error banner if present,
    input raws list, prompt sent (collapsible monospace),
    raw LLM response (collapsible), parsed JSON (collapsible), distribution
    log (color-coded "added" green / "skipped" orange).
  - Empty state: "No classifier run captured yet. Tap Process on the
    Capture screen with at least one raw entry, then come back."
  - Uses `Theme.LayeredBackground`, `themedCard`, `Theme.Typography`,
    `Theme.Spacing`. Includes the standard `Color.clear.frame(height: 96)`
    tab-bar clearance per UI rules.
  - `CollapsibleMonoCard` private subview — header label + Expand/Collapse
    toggle, monospace footnote text inside a paper-tinted card. Text is
    selectable via `.textSelection(.enabled)` so the user can copy the
    prompt or response.

- `Sarvis/Screens/SettingsView.swift`
  - New `debugCard` section appended after `actionsRow`. Contains a single
    `NavigationLink` row: "View last classifier run" → `ClassifierDebugView`,
    plus a one-line description below the divider. No on/off toggle —
    living in Settings already keeps it out of the main flow.

No changes to news/MorningJob code. No changes to InputView (it's the call
site; `runClassifier` doesn't need to know about the debug record).

## 2. App icon — monkey

- Source: `~/Downloads/output.jpg` (640×640, opaque, JPEG).
- Built a 1024×1024 opaque PNG master via `sips -s format png -z 1024 1024`.
- Generated 18 PNGs (iPhone + iPad + marketing) into
  `Sarvis/Resources/Assets.xcassets/AppIcon.appiconset/` using `sips -z`.
- Rewrote `Contents.json` with the full size→filename map covering iPhone
  20/29/40/60 @2x and @3x, iPad 20/29/40 @1x and @2x, iPad 76 @1x/@2x,
  iPad Pro 83.5 @2x, and ios-marketing 1024.
- `project.yml` already had `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`;
  no changes needed there.
- Ran `xcodegen generate` once (to pick up the new Swift file from step 1).

## Build status

`xcodebuild -project Sarvis.xcodeproj -scheme Sarvis -destination
'generic/platform=iOS Simulator' build` → BUILD SUCCEEDED. Only
pre-existing `@frozen has no effect on non-public enums` warnings on
`AnyCodableValue.swift`. No icon-related warnings.

## STATE.md

Added a 2026-04-26 update-log entry for `debug-viewer-and-icon` and
appended `ClassifierDebugView (Settings → Debug)` to the Screens row in
the architecture map.
