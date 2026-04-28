# Phase 2.3 — Custom notification UI

Add a Notification Content Extension that renders SwiftUI for expanded notifications. Ship all three category templates in this pass. Spec: `docs/phase-2.md` §2.3.

- [x] Read `docs/phase-2.md` §2.3, `Sarvis/Services/NotificationService.swift`, `project.yml` (target structure for `Sarvis` and `SarvisWidget`), `Sarvis/UI/Theme.swift`. Note how `SarvisWidget` is wired as a target + dependency — mirror that shape for the new extension target
- [x] Add new target `SarvisNotificationContent` to `project.yml` (use a targeted Edit — do not full-rewrite). Bundle ID `com.shrey.sarvis.notification-content`. `Info.plist` keys: `NSExtension.NSExtensionPointIdentifier = com.apple.usernotifications.content-extension`; `NSExtension.NSExtensionAttributes.UNNotificationExtensionCategory = ["task.reminder", "news.briefing", "quote.morning"]`; `UNNotificationExtensionInitialContentSizeRatio = 1.0`. Use `CODE_SIGN_STYLE: Automatic` and `DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)` like the widget. Add it as an embedded dependency on the `Sarvis` target
- [x] Create the extension sources under `SarvisNotificationContent/`:
  - `NotificationViewController.swift` — `UIViewController, UNNotificationContentExtension`. In `didReceive(_ notification:)`, dispatch to a SwiftUI router view based on `notification.request.content.categoryIdentifier`. Host via `UIHostingController` added as a child VC, pinned to bounds.
  - `NotificationContentView.swift` — top-level SwiftUI router that picks one of three subviews by category.
  - Three subviews:
    - `TaskReminderView` — title (serif), body, importance dot (palette-keyed), due-time chip ("Today 3:00 PM").
    - `MorningBriefingView` — date header, headline summary, 2–3 bullet headlines.
    - `QuoteCardView` — quote body in serif, attribution, soft accent.
  - All views use Theme tokens. The extension can't import the host app's `Theme.swift` directly across target boundaries — duplicate the token values needed (Spacing, Radius, Typography fonts, Palette colors) into a small `ExtensionTheme.swift` inside `SarvisNotificationContent/`. Don't reach into the host app.
- [x] Create `SarvisNotificationContent/Info.plist` (or let XcodeGen generate one via `info.properties:`). Use the latter if XcodeGen is already generating Info.plists for other targets — keep it consistent — used `info.properties:` in project.yml, XcodeGen generates the plist
- [x] Encode payload contract: extensions read fields from `notification.request.content.userInfo`. Define a small dictionary contract per category (e.g., for `task.reminder`: `{"importance": "high|med|low", "dueAt": ISO8601 string}`). Document the contract at the top of `NotificationContentView.swift`
- [x] Update `Sarvis/Services/NotificationService.swift` — `schedule(title:body:at:)` and any sibling schedulers (`MorningJob`, `QuoteJob`) must set `UNMutableNotificationContent.categoryIdentifier` per type and populate `userInfo` with the expected fields. Register the three categories with their identifiers via `UNUserNotificationCenter.current().setNotificationCategories(_:)` at app init (likely in `SarvisApp.init()` or `NotificationService.requestPermission()` — pick whichever already runs once at startup)
- [x] Run `xcodegen generate`. Confirm `Sarvis.xcodeproj` rebuilds with the new extension target embedded. Run `xcodebuild -scheme Sarvis -destination "generic/platform=iOS Simulator" -configuration Debug build` (or simulator-specific equivalent) and confirm BUILD SUCCEEDED — the existing widget extension is the analogue, model after it
- [x] If `xcodebuild` fails for any reason that's NOT codesign-related (e.g., missing Info.plist key, wrong NSExtensionPointIdentifier, type mismatch), fix it. If it's a codesign issue specific to the user's local environment (no provisioning profile yet for the new bundle ID), mark the build item with a note explaining the user will need to register `com.shrey.sarvis.notification-content` as an App ID in Apple Developer portal — don't block on this
- [x] Update `STATE.md` update-log: append a 2026-04-27 entry "Phase 2.3 — Notification Content Extension shipped with three category templates (task.reminder, news.briefing, quote.morning)"
- [x] In `docs/phase-2.md` §2.3, mark scope items as shipped
- [x] Write summary (files added, project.yml shape changes, payload contract per category, any codesign caveats user must resolve before device testing) to `.dispatch/tasks/notif-ui/output.md`
- [x] `touch .dispatch/tasks/notif-ui/ipc/.done`
