# Morning Briefing + Quote Pings — Implementation Summary

## Morning task identifier
`com.shrey.sarvis.morning`  
Registered via `BGTaskScheduler` in `MorningJob.register()`, which must (and does) run in `SarvisApp.init()` before the app finishes launching.

## Scheduling cadence

| Job | Mechanism | Target time |
|-----|-----------|-------------|
| Morning briefing | `BGAppRefreshTask` | ~7:00 AM local, best-effort |
| Morning quote | `UNCalendarNotificationTrigger` | 9:30 AM local, exact |
| Afternoon quote | `UNCalendarNotificationTrigger` | 14:00–18:00 local (deterministic per day-of-year) |

`MorningJob.scheduleNext()` and `QuoteJob.scheduleDailyPings()` are both called from `.onAppear` on the root scene on every app launch, keeping everything fresh.

## Quote source layering (seed + accumulated)
`QuoteService.loadAll()` merges two sources, deduped on lowercased text:
1. **Bundle seed** — `Sarvis/Resources/Quotes/seed.json` (35 quotes, shipped with the app).
2. **Accumulated** — `Documents/processed/quotes.json` — the LLM (or any future pipeline) can append quotes here over time; they are picked up automatically on the next launch.

`QuoteService.random()` draws a uniform random pick from the merged pool.

## Why the body is baked at schedule time
iOS does not allow a notification's body to be computed dynamically at fire time without a **Notification Service Extension** (a separate target that intercepts the push just before display). That extension requires APNs + a server-side push; it cannot intercept local `UNCalendarNotificationTrigger` notifications without extra infra. To avoid that complexity, `QuoteJob.scheduleDailyPings()` picks a random quote on app launch, embeds the text in `UNMutableNotificationContent.body`, and schedules the notification with the body already set. Re-running on every launch keeps the quote fresh (today's pick changes each day the user opens the app).

The same principle applies to the morning briefing: `MorningJob` fires during a `BGAppRefreshTask`, runs the full LLM pipeline, and then schedules a local notification with the baked summary string — no extension needed.

## Known iOS background limitations
- `BGAppRefreshTask` is **best-effort**. The OS can delay, throttle, or skip the task entirely based on battery level, network, and usage patterns. If the user never opens the app at night, the task may not fire until mid-morning.
- iOS limits background CPU time per task invocation (~30 seconds typical). The `expirationHandler` in `MorningJob` cancels the async work and calls `setTaskCompleted(success: false)` if the budget runs out.
- Simulator does not run background tasks automatically; use the LLDB technique below for testing.
- `BGTaskSchedulerPermittedIdentifiers` must match exactly — `com.shrey.sarvis.morning` is now declared in `Info.plist` via `project.yml`.

## How to test
**Simulating the background task in Xcode:**
1. Run the app on device or simulator.
2. Pause in the Xcode debugger.
3. In the LLDB console run:
   ```
   e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.shrey.sarvis.morning"]
   ```
4. Resume. The task handler fires immediately.

**Quote pings:** Change the hour/minute in `QuoteJob.scheduleQuote` to fire 1 minute in the future, launch the app, background it, and wait.

**Full end-to-end check list:**
- [ ] API key set in Keychain (via SettingsView).
- [ ] GNews API key set (if required by `GNewsProvider`).
- [ ] Notification permission granted.
- [ ] LLDB simulate command fires the task.
- [ ] Notification appears with a ≤5-sentence digest.

## How to upgrade later (dynamic notification content)
To compute notification body at fire time without requiring the app to be open:
1. Add a **UNNotificationServiceExtension** target (`SarvisNotificationService`).
2. Send a silent APNs push with `content-available: 1` and a payload key (e.g. `"fetch": "morning"`).
3. In the extension's `didReceive(_:withContentHandler:)`, call the LLM or read a cached summary from a shared App Group container, set `bestAttemptContent.body`, and call the handler.
4. The 30-second service extension budget is generous enough for a local read; for an LLM call you'd pre-stage the summary in a shared container during the BGAppRefreshTask and just read it in the extension.

This removes the dependency on the user opening the app before notifications fire.
