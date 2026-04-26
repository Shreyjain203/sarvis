# finish-widget — completion summary

## Final widget file inventory

| File | Status |
|------|--------|
| `SarvisWidget/SarvisWidgetBundle.swift` | Renamed from `ReminderWidgetBundle.swift`; `@main struct SarvisWidgetBundle` |
| `SarvisWidget/QuickCaptureWidget.swift` | Complete — `StaticConfiguration`, `.systemSmall` + `.systemMedium` |
| `SarvisWidget/QuickCaptureProvider.swift` | Complete — static single entry, `policy: .never` |
| `SarvisWidget/QuickCaptureView.swift` | Complete — faux text-box pill, submit pill, `Link(sarvis://capture)`, `.containerBackground(.fill.tertiary)`, fixed "Reminder" → "Sarvis" label |
| `SarvisWidget/WidgetTheme.swift` | Complete — self-contained design tokens; no cross-target imports |
| `SarvisWidget/Info.plist` | Unchanged (already correct) |
| `Sarvis/Screens/QuickCaptureSheet.swift` | New — focused TextField sheet, Submit guard, TodoStore.capture, ToastCenter |
| `Sarvis/App/RootView.swift` | Additive edit — `@State showCaptureSheet`, `.onOpenURL`, `.sheet(QuickCaptureSheet)` |

## URL scheme contract

`sarvis://capture` → any tap on the widget fires this URL → iOS delivers it to the host app → `RootView.onOpenURL` sets `showCaptureSheet = true` → `QuickCaptureSheet` appears as a modal sheet with the keyboard already raised.

## Visual + interaction flow

1. **Widget (home screen):** Shows a rounded faux text-box ("Capture a note…") and a filled "Submit" pill button. Both layouts (small 2×2, medium 4×2) wrap the whole view in a `Link` — any tap opens the host app.
2. **Deep link → sheet:** iOS opens Sarvis via the `sarvis://` URL scheme. `RootView` intercepts the URL and presents `QuickCaptureSheet` as a sheet.
3. **Sheet:** A `TextField` (multi-line, `.axis: .vertical`) auto-focuses after a 150 ms delay so the keyboard rises immediately. The Submit button is disabled until the user types non-whitespace text.
4. **Save → toast → dismiss:** Tapping Submit calls `TodoStore.shared.capture(text:type:.note:importance:.medium:isSensitive:false:dueAt:nil)`, then `ToastCenter.shared.show("Captured")`, then `dismiss()`. The whole interaction takes ~2 seconds.

## Why interactive text input is impossible inside the widget

WidgetKit renders widgets as **remote view archives** (essentially snapshots), not live view hierarchies. The widget process has no run loop capable of hosting a `UITextField`/`SwiftUI TextField` responder. SwiftUI simply ignores any interactive controls inside a `WidgetConfiguration` content closure at render time. The `Link` wrapper is the approved workaround: it encodes a URL in the snapshot and iOS delivers it to the host app on tap.

**Upgrade path:** If Apple ever enables App Intent-based interactive widgets (currently limited to buttons and toggles, not free-text input), the provider could be migrated to `AppIntentTimelineProvider` and a `StringIntent` parameter — but free-text fields inside the widget are still not on the public roadmap as of iOS 17/18.

## Install instructions

1. Build the `Sarvis` scheme to a real device (widget extensions don't run in the simulator's home screen).
2. After install, long-press the home screen → tap **+** → search **Sarvis** → choose **Quick Capture** → select small or medium size → tap **Add Widget**.
3. Tap the widget once to verify it opens the capture sheet with the keyboard raised.
