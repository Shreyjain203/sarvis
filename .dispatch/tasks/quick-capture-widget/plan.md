# Quick-capture widget + deep-link sheet

iOS widget with a faux text-box + submit button that deep-links into a focused capture sheet in the host app. The sheet writes via the existing `TodoStore.shared.capture(...)` API as a `.note`.

**Why faux:** WidgetKit does NOT support live `TextField` input. The widget renders a tappable pill that looks like a text input; tapping it opens the host app via URL scheme to a sheet that has the real keyboard.

- [ ] **Add URL scheme to the app.** In `project.yml`, under the `ReminderApp` target's `info.plist` section (or in a separate Info.plist if one exists), add `CFBundleURLTypes` with scheme `reminderapp`. Re-run `xcodegen generate` after editing.
- [ ] **Add a Widget Extension target** in `project.yml`:
  - Target name: `ReminderWidget`
  - Type: `app-extension`
  - Platform: iOS 17+
  - Bundle ID: `com.shrey.reminder.widget` (child of host app's bundle ID)
  - Sources: `ReminderWidget/`
  - Required frameworks: `WidgetKit`, `SwiftUI`, `AppIntents`
  - Embed into the main app target via `dependencies`.
  - Info.plist: include `NSExtension` with `NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
- [ ] **Create `ReminderWidget/` folder with these Swift files:**
  - `ReminderWidgetBundle.swift` — `@main struct ReminderWidgetBundle: WidgetBundle { var body: some Widget { QuickCaptureWidget() } }`.
  - `QuickCaptureWidget.swift` — `struct QuickCaptureWidget: Widget` with a `StaticConfiguration`. Supported families: `.systemSmall`, `.systemMedium`. `configurationDisplayName: "Quick Capture"`, `description: "Jot a note in one tap."`.
  - `QuickCaptureProvider.swift` — minimal `TimelineProvider` (placeholder + snapshot + timeline returning a single static entry — the widget has no dynamic data).
  - `QuickCaptureView.swift` — the SwiftUI view. Layout: a faux text-box pill (rounded rect with placeholder "Capture a note…" in a muted color) + a small filled "Submit" pill button. The whole widget is wrapped in `Link(destination: URL(string: "reminderapp://capture")!)` so any tap deep-links into the host app. Use `.containerBackground(.fill.tertiary, for: .widget)` for iOS 17+ widget background.
- [ ] **Theme inside widget:** widget extensions can't share an arbitrary file unless added to the widget's sources. Copy the **minimum** Theme constants needed (palette colors, spacing, radii) into `ReminderWidget/WidgetTheme.swift`. Keep it tiny — only what the view uses. Do NOT import the full Theme.swift.
- [ ] **Host app: handle the deep link.**
  - In `ReminderApp/App/ReminderAppApp.swift` (or `RootView.swift`, whichever owns the top scene), add `.onOpenURL { url in ... }` that detects `url.scheme == "reminderapp"` and `url.host == "capture"`, then sets a `@State`/`@StateObject` flag to present a sheet.
  - Create `ReminderApp/Screens/QuickCaptureSheet.swift` — small sheet view: `TextField` with `.focused()` auto-focus on appear, a Submit button, and `.dismissKeyboardToolbar()` applied. Submit calls `TodoStore.shared.capture(text: text, type: .note, importance: .medium, isSensitive: false, dueAt: nil)`, then `ToastCenter.shared.show("Captured")`, then dismisses the sheet. Use `Theme` styling consistent with `InputView`.
  - Cancel button (or swipe-down) dismisses without saving.
- [ ] **App Intent (optional but nicer UX):** add `ReminderWidget/CaptureIntent.swift` defining a small `AppIntent` with a `text: String` parameter and a `perform()` that opens the host app via deep link. This is a stub — for now the widget tap just uses the `Link` URL deep-link approach above. Mark as `// TODO: bind to interactive widget once iOS 17 interactive widget API supports text input`.
- [ ] **Run `swift -frontend -parse`** on every new/modified Swift file:
  - `ReminderWidget/ReminderWidgetBundle.swift`
  - `ReminderWidget/QuickCaptureWidget.swift`
  - `ReminderWidget/QuickCaptureProvider.swift`
  - `ReminderWidget/QuickCaptureView.swift`
  - `ReminderWidget/WidgetTheme.swift`
  - `ReminderApp/Screens/QuickCaptureSheet.swift`
  - `ReminderApp/App/ReminderAppApp.swift` (or wherever `.onOpenURL` was added)
  - Report any errors.
- [ ] **Run `xcodegen generate`** to regenerate the `.xcodeproj` with the new widget target and URL scheme. Confirm exit code 0.
- [ ] Write a summary to `.dispatch/tasks/quick-capture-widget/output.md` describing:
  - The widget visual + interaction (faux text-box → deep link → sheet).
  - The URL scheme contract (`reminderapp://capture`).
  - Files added and where they live.
  - Why interactive text input isn't possible inside the widget itself (WidgetKit limitation) and the upgrade path if Apple ever adds it.
  - How to install: add the widget from the home screen long-press menu after building to device.

**External dependencies (already in place):**
- `TodoStore.shared.capture(text:type:importance:isSensitive:dueAt:)` — built by the storage-refactor worker.
- `ToastCenter.shared.show(_:)` and `.dismissKeyboardToolbar()` — built by the toast-and-keyboard worker.
- `InputType.note` enum case — built by the storage-refactor worker.

**Constraints:**
- iOS 17+ (uses `.containerBackground(_:for:)` and modern widget APIs).
- No third-party deps.
- Don't break the existing host app build — the widget target is additive.
- Bundle ID must be a child of host app's bundle ID for embedding to work.
- Atomic writes everywhere `TodoStore` already handles them — don't re-implement.
