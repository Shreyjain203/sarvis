# Phase 2.3 — Notification Content Extension — Completion Report

**Date:** 2026-04-27  
**Build status:** BUILD SUCCEEDED (iOS Simulator)

---

## Files added

| Path | Purpose |
|------|---------|
| `SarvisNotificationContent/NotificationViewController.swift` | `UIViewController + UNNotificationContentExtension`; hosts SwiftUI via `UIHostingController` pinned to bounds |
| `SarvisNotificationContent/NotificationContentView.swift` | Top-level SwiftUI router; dispatches to subview by `categoryIdentifier`; payload contract documented at top |
| `SarvisNotificationContent/TaskReminderView.swift` | `task.reminder` template — importance dot, serif title, body, due-time chip |
| `SarvisNotificationContent/MorningBriefingView.swift` | `news.briefing` template — date header, headline, bullet list (2–3 items) |
| `SarvisNotificationContent/QuoteCardView.swift` | `quote.morning` template — serif quote, attribution, soft accent gradient |
| `SarvisNotificationContent/ExtensionTheme.swift` | Duplicate of host-app Theme tokens (Spacing, Radius, Typography, Palette) — no cross-target import |

---

## project.yml changes

- Added `SarvisNotificationContent` target (type `app-extension`, `CODE_SIGN_STYLE: Automatic`, `DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)`) with `Info.plist` generated via `info.properties:` (matches SarvisWidget pattern).
- Bundle ID: `com.shrey.sarvis.notification-content`
- Info.plist keys set: `NSExtensionPointIdentifier = com.apple.usernotifications.content-extension`, `UNNotificationExtensionCategory = [task.reminder, news.briefing, quote.morning]`, `UNNotificationExtensionInitialContentSizeRatio = 1.0`.
- Added as embedded dependency on `Sarvis` target (alongside existing `SarvisWidget`).

---

## Host-app changes

**`Sarvis/Models/TodoItem.swift`**
- Added `Importance.notifString` property returning `"low"/"med"/"high"/"critical"` for notification `userInfo`.

**`Sarvis/Services/NotificationService.swift`**
- Added category constants: `categoryTaskReminder`, `categoryNewsBriefing`, `categoryQuoteMorning`.
- `registerCategories()` now registers all three new content-extension categories plus the legacy `TODO_REMINDER` category.
- `schedule(_:at:)` (TodoItem overload) now uses `categoryTaskReminder` and populates `userInfo["importance"]` + `userInfo["dueAt"]` (ISO 8601).
- `schedule(title:body:at:importance:)` raw overload updated similarly.

**`Sarvis/Services/Jobs/MorningJob.swift`**
- `scheduleNotification(body:)` sets `categoryIdentifier = "news.briefing"` and populates `userInfo["headline"]` (first sentence) + `userInfo["bullets"]` (remaining sentences joined by `\n`, up to 3).

**`Sarvis/Services/Jobs/QuoteJob.swift`**
- `scheduleQuote(_:id:hour:minute:)` sets `categoryIdentifier = "quote.morning"` and populates `userInfo["quote"]` + `userInfo["attribution"]`.

---

## Payload contract per category

### `task.reminder`
```
userInfo["importance"] = "low" | "med" | "high" | "critical"
userInfo["dueAt"]      = ISO 8601 string (e.g. "2026-04-27T15:00:00Z")
```
Title and body from `UNNotificationContent.title` / `.body`.

### `news.briefing`
```
userInfo["headline"] = one-sentence summary string
userInfo["bullets"]  = newline-separated list of 2–3 bullet headlines
```
Title from `UNNotificationContent.title` (e.g. "Today's briefing").

### `quote.morning`
```
userInfo["quote"]       = quote body text
userInfo["attribution"] = attribution string (e.g. "— Marcus Aurelius")
```
Title from `UNNotificationContent.title` (e.g. "Daily quote").

---

## Codesign caveat (user action required before device testing)

The new bundle ID `com.shrey.sarvis.notification-content` must be registered as an explicit App ID in the Apple Developer portal under the same team before building for a physical device. Steps:

1. Go to [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → Identifiers.
2. Add a new App ID with bundle ID `com.shrey.sarvis.notification-content`.
3. Enable the "App Groups" capability if you intend to share data between host app and extension (not needed currently).
4. Regenerate provisioning profiles (Xcode → Preferences → Accounts → Download Manual Profiles, or let Xcode Automatic Signing handle it after the App ID is registered).

The simulator build succeeds today without this step. Physical-device codesign will fail until the App ID exists.
