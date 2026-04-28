# Phase 2.4 — Widget re-enable

Bring `SarvisWidget` back online with a single `systemLarge` family. Strip to a big text-field-shaped tap target + Submit pill. Both deep-link to `sarvis://capture`. Spec: `docs/phase-2.md` §2.4.

- [x] Read `docs/phase-2.md` §2.4, `project.yml` (find the commented `SarvisWidget` target block + the disabled `dependencies:` entry on `Sarvis`), and `SarvisWidget/` source files to understand the existing widget shape before changing it
- [x] Re-enable `SarvisWidget` in `project.yml`: uncomment the target block; restore the `dependencies:` entry on the `Sarvis` target with `embed: true`
- [x] Verify codesign config: both targets share the same `DEVELOPMENT_TEAM`; widget bundle ID is `com.shrey.sarvis.widget`. Both targets use `CODE_SIGN_STYLE: Automatic`; widget gets `DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)` to ensure inheritance. Host target already relied on global Automatic signing.
- [x] Trim `SarvisWidget/QuickCaptureWidget.swift`: dropped `systemSmall` and `systemMedium`; now `.supportedFamilies([.systemLarge])` only.
- [x] Built `systemLarge` UI in `QuickCaptureView.swift`: `GeometryReader`-based layout — header row, faux text field at ~55% height (`"What's on your mind?"` placeholder in rounded rect), wide Submit `Capsule` pill at bottom. Both wrapped in separate `Link(destination: captureURL)`. Updated `WidgetTheme.swift` with `canvasBackground`, `textField` radius token (16pt), kept `pill` radius.
- [x] Confirmed host-app `RootView.onOpenURL` handles `sarvis://capture` (line 30-33): `url.scheme == "sarvis" && url.host == "capture"` → `showCaptureSheet = true` → `QuickCaptureSheet()`. Present from Phase 1, no change needed.
- [x] Ran `xcodegen generate` — clean output, `Sarvis.xcodeproj` rebuilt with widget target restored, no schema errors.
- [x] Update `STATE.md` update-log with a 2026-04-27 entry
- [x] In `docs/phase-2.md` §2.4, mark items as shipped
- [x] Write summary to `.dispatch/tasks/widget-relaunch/output.md`
- [x] `touch .dispatch/tasks/widget-relaunch/ipc/.done`
