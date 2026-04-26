# Finish the quick-capture widget + deep-link sheet

The earlier widget worker hit a rate limit partway. The folder `SarvisWidget/` exists with partial files — finish them, fix anything stale, and add the host-app sheet that handles the deep link.

**Existing files in `SarvisWidget/`:**
- `Info.plist` (✓)
- `QuickCaptureProvider.swift` (stub — verify)
- `QuickCaptureView.swift` (substantial — already updated to `sarvis://` scheme by rename worker)
- `QuickCaptureWidget.swift` (stub — verify)
- `ReminderWidgetBundle.swift` (**still has old name — rename to `SarvisWidgetBundle.swift` and rename inner type `ReminderWidgetBundle` → `SarvisWidgetBundle`**)
- `WidgetTheme.swift` (verify)

- [x] **Inspect every existing file in `SarvisWidget/`** with Read. List what's present and what's stub. — All 6 files read. Bundle stub has old name; QuickCaptureWidget, Provider, View, WidgetTheme are complete/correct.
- [x] **Rename `ReminderWidgetBundle.swift` → `SarvisWidgetBundle.swift`** and update the `@main struct ReminderWidgetBundle` → `SarvisWidgetBundle`. Confirm `body` returns `QuickCaptureWidget()`. — Done. File renamed and struct type updated.
- [x] **Verify / complete `QuickCaptureWidget.swift`:** — Already complete and correct. StaticConfiguration, displayName, description, supportedFamilies, QuickCaptureView all present.
- [x] **Verify / complete `QuickCaptureProvider.swift`:** — Already complete. All three methods return a single static entry; policy: .never.
- [x] **Verify `QuickCaptureView.swift`:** — All requirements met. Fixed "Reminder" label in small layout → "Sarvis". Link wraps whole view, containerBackground used, WidgetTheme tokens throughout.
- [x] **Verify `WidgetTheme.swift`:** — Complete. Self-contained enum with Spacing, Radius, ink/muted/hairline/inputBackground/buttonBackground/buttonForeground. No cross-target imports.
- [x] **Add the host-app deep-link sheet** at `Sarvis/Screens/QuickCaptureSheet.swift`: — Created. TextField with @FocusState auto-focus, Submit disabled when blank, calls TodoStore.shared.capture, ToastCenter.shared.show("Captured"), dismisses. dismissKeyboardToolbar applied. Themed to match InputView.
  - SwiftUI sheet view: focused `TextField` (auto-focus on appear via `@FocusState`), a Submit button, and Cancel.
  - `.dismissKeyboardToolbar()` applied to the sheet's container.
  - Submit calls `TodoStore.shared.capture(text: text, type: .note, importance: .medium, isSensitive: false, dueAt: nil)`, then `ToastCenter.shared.show("Captured")`, then dismisses (`@Environment(\.dismiss)`).
  - Empty-text guard: Submit is disabled if `text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`.
  - Use `Theme` styling consistent with `Sarvis/Screens/InputView.swift` — themed card, serif title "Quick capture", spacing scale.
- [x] **Wire deep-link handling in the host app.** — Added to `RootView.swift` (chosen over SarvisApp.swift to avoid conflict with composer worker). Added @State showCaptureSheet, .onOpenURL checking scheme==sarvis && host==capture, .sheet presenting QuickCaptureSheet.
  - A `@State private var showCaptureSheet = false` somewhere in the scene.
  - `.onOpenURL { url in if url.scheme == "sarvis" && url.host == "capture" { showCaptureSheet = true } }`.
  - `.sheet(isPresented: $showCaptureSheet) { QuickCaptureSheet() }`.
  - Note: `dynamic-ui-composer` worker might also be touching `SarvisApp.swift` (to add `ElementRegistry.shared.registerBuiltIns()` in `init()`). Make minimal, additive edits there. If your edit conflicts with theirs, add the `.onOpenURL` handler to `RootView.swift` instead and document it.
- [x] **Confirm `project.yml` already has the URL scheme entry** (`sarvis://`) — Confirmed. CFBundleURLTypes with CFBundleURLSchemes: [sarvis] is present under the Sarvis target.
- [x] **Confirm `project.yml` has the `SarvisWidget` target** — Confirmed. type: app-extension, PRODUCT_BUNDLE_IDENTIFIER: com.shrey.sarvis.widget, embedded via Sarvis target dependency with embed: true.
- [x] **Run `swift -frontend -parse`** on every new + modified Swift file:
  - `SarvisWidget/SarvisWidgetBundle.swift`
  - `SarvisWidget/QuickCaptureWidget.swift`
  - `SarvisWidget/QuickCaptureProvider.swift`
  - `SarvisWidget/QuickCaptureView.swift`
  - `SarvisWidget/WidgetTheme.swift`
  - `Sarvis/Screens/QuickCaptureSheet.swift`
  - Whichever of `Sarvis/App/SarvisApp.swift` / `Sarvis/App/RootView.swift` you edited.
  Report any errors. — All 7 files parsed with no errors.
- [x] **Run `xcodegen generate`** — Exit code 0. Project regenerated at Sarvis.xcodeproj with new files included.
- [x] Write a summary to `.dispatch/tasks/finish-widget/output.md` describing:
  - Final widget file inventory.
  - URL scheme contract: `sarvis://capture` opens the focused capture sheet.
  - Visual + interaction (faux text-box → deep link → sheet → save → toast).
  - Why interactive text input isn't possible inside the widget itself (WidgetKit limitation), and the upgrade path if iOS ever supports it.
  - Install instructions: build to device, then add the widget from the home screen long-press menu. — Written to output.md.

**Constraints:**
- iOS 17+. `.containerBackground(_:for:)` and modern widget APIs.
- No third-party deps.
- **Don't touch any file under `Sarvis/UI/Composer/` or `Sarvis/UI/Elements/`** — that's the parallel `dynamic-ui-composer` worker's territory.
- **Don't touch `Sarvis/Screens/InputView.swift`** — composer worker may retrofit it.
- **Minimal edits to `Sarvis/App/SarvisApp.swift`.** Both workers may want to edit it. Keep your edit small and additive (`.onOpenURL` + `.sheet` only). If a merge conflict happens, route through `RootView.swift` instead.
- Bundle ID `com.shrey.sarvis.widget` must remain a child of the host app's bundle ID for embedding to work.
