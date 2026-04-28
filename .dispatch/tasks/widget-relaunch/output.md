# Widget Re-enable — Output

## Files modified

| File | Change |
|---|---|
| `project.yml` | Uncommented `SarvisWidget` target block and `dependencies:` entry on `Sarvis` target. Added `DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)` to widget's settings block. |
| `SarvisWidget/QuickCaptureWidget.swift` | Changed `.supportedFamilies` from `[.systemSmall, .systemMedium]` to `[.systemLarge]` only. |
| `SarvisWidget/QuickCaptureView.swift` | Full rewrite: dropped `systemSmall`/`mediumLayout` switch; new `systemLarge`-only layout with `GeometryReader`-based proportions — header row, faux text field at ~55% height, wide Submit `Capsule` pill. Both tap targets wrapped in `Link(destination: URL(string: "sarvis://capture")!)`. |
| `SarvisWidget/WidgetTheme.swift` | Added `canvasBackground` color token and `Radius.textField` (16pt) token alongside existing `Radius.pill`. |
| `STATE.md` | Added 2026-04-27 update-log entry. |
| `docs/phase-2.md` | Marked widget item in Definition of Done as `[x]`. |

## Codesign notes

Both targets use `CODE_SIGN_STYLE: Automatic`. The widget target now explicitly declares `DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)` so Xcode uses the same team as the host app without hardcoding the team ID. This was the likely cause of the Phase 1 device codesign failure — the widget target had no explicit team setting, which can cause extension codesign to diverge from the host when building on a physical device.

## Deep-link verification

`RootView.onOpenURL` (lines 30-34) already handles `sarvis://capture` from Phase 1:
```swift
.onOpenURL { url in
    if url.scheme == "sarvis" && url.host == "capture" {
        showCaptureSheet = true
    }
}
```
No change needed.

## xcodegen

`xcodegen generate` completed cleanly — `Sarvis.xcodeproj` rebuilt with `SarvisWidget` target present.

## Anything surprising

- The existing `QuickCaptureView.swift` used an `@Environment(\.widgetFamily)` switch but never had a `systemLarge` case — it fell through to `mediumLayout`. The full rewrite removes that switch entirely since only one family is supported.
- `AppIntents.framework` dependency kept in the widget target (was already there); harmless for now, needed if App Intents are added later.
