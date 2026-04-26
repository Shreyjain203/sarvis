# Morning newspaper push + scheduled motivational quotes

Two scheduled jobs: (1) a morning briefing combining yesterday/today's news as a notification (newspaper role); (2) a motivational-quote ping 1–2 times per day at quasi-random hours.

**Scope:**
- Background fetching uses `BGAppRefreshTask` (best-effort iOS scheduling).
- Quote pings use `UNCalendarNotificationTrigger` for deterministic times.
- Quote source: a seed JSON shipped in the bundle (`Sarvis/Resources/Quotes/seed.json`) plus anything the LLM has appended to `Documents/processed/quotes.json` over time.
- News summary uses the existing `prompts/news_summary.md` prompt and `LLMService` (Anthropic). Stores summary at `Documents/processed/news/<YYYY-MM-DD>.json`.

- [x] **Add seed quotes file** at `Sarvis/Resources/Quotes/seed.json` — JSON array of 30–40 short motivational quotes (each: `{ "text": "...", "author": "..." }`). Make them feel like the user's voice — direct, no fluff, not generic LinkedIn pap. Add it as a bundle resource in `project.yml` (next to the `Prompts/` resource). — 35 quotes written; Quotes/ resource added to project.yml.
- [x] **Add `Sarvis/Services/Quotes/QuoteService.swift`** — `@MainActor final class QuoteService`:
  - `func loadAll() -> [Quote]` — bundle seed + Documents-stored quotes (deduped on text).
  - `func random() -> Quote?` — uniform random pick.
  - `struct Quote: Codable, Hashable { let text: String; let author: String? }`.
- [x] **Add `Sarvis/Services/Jobs/QuoteJob.swift`** — `@MainActor enum QuoteJob`:
  - `static func scheduleDailyPings()` — schedules two `UNCalendarNotificationTrigger`s: one morning (e.g. 9:30 AM local) and one afternoon at a quasi-random hour (use `seed = Date.dayOfYear` to pick an hour in 14:00–18:00 deterministically per day so we don't double-stack).
  - On firing, the notification body is a randomly-picked quote. Implement via static notification content + a custom `UNNotificationServiceExtension`-style body? **No** — we can't compute body at fire time without an extension. So instead: every time `scheduleDailyPings` runs (e.g. on app launch), tear down existing pings and re-schedule today's two with the body baked in. Simple and good enough.
- [x] **Add `Sarvis/Services/Jobs/MorningJob.swift`** — `@MainActor enum MorningJob`:
  - `static func register()` — calls `BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.shrey.sarvis.morning", using: nil)` with a handler.
  - `static func scheduleNext()` — submits a `BGAppRefreshTaskRequest` for the next morning ~7 AM local. Best-effort.
  - Handler logic: `try await NewsService.shared.refreshToday()` → take top N articles → call `LLMService` with `PromptLibrary.body(for: "news_summary", fallback: ...)` substituting `{{articles}}` → store summary via `DailyArtifactStore` under folder `"news"` for today's date → schedule a notification with title "Today's briefing" and the LLM summary as body.
  - Handler must call `task.setTaskCompleted(success:)` exactly once. Use `task.expirationHandler` to cancel work if iOS pulls the rug.
- [x] **Wire registration in `Sarvis/App/SarvisApp.swift`** `init()`:
  - Add `MorningJob.register()` (must be called BEFORE the app finishes launching — `init()` is fine).
  - In `body` (or use `.onAppear` on the root scene), call `MorningJob.scheduleNext()` and `QuoteJob.scheduleDailyPings()` after launch.
  - Don't break the existing `ElementRegistry.shared.registerBuiltIns()` call already in `init()`. Add the new lines adjacent to it.
- [x] **Add Background Modes capability** in `project.yml`:
  - Under the `Sarvis` target's `Info.plist` keys (or wherever capabilities are declared), add `UIBackgroundModes: [fetch, processing]`.
  - Add `BGTaskSchedulerPermittedIdentifiers: [com.shrey.sarvis.morning]`.
  - Re-run `xcodegen generate`.
- [x] **Add prompt file `prompts/quote_pick.md`** — a tiny prompt for selecting/generating a quote from the user's recent profile (placeholder body for now). Sync via `tools/sync-prompts.sh`. The MVP doesn't actually call this — it's a placeholder for the future "personalized quote" upgrade.
- [x] **Verification:** `swift -frontend -parse` on every new + modified file. `xcodegen generate` exit 0. — All 4 Swift files parse clean; xcodegen exits 0.
- [x] Write a summary to `.dispatch/tasks/morning-and-quotes-jobs/output.md` covering: the morning task identifier, scheduling cadence, quote source layering (seed + accumulated), why the body is baked at schedule time (notification extension complexity), known iOS BG limitations, how to test (Xcode debugger has a `BGTaskScheduler._simulateLaunchForTaskWithIdentifier:` LLDB command), and how to upgrade later (notification service extension + dynamic content).

**Constraints:**
- iOS 17+. No third-party deps.
- Don't touch `Sarvis/Models/`, `Sarvis/UI/Elements/`, or `Sarvis/Services/Storage/` (other than calling existing APIs).
- Don't touch `Sarvis/Services/News/` source (just call `NewsService.shared` from your code).
- A parallel worker (`classifier-pipeline`) is editing `Sarvis/Services/LLM/`, `prompts/`, and capture screens — don't edit any of those. (You're adding a NEW prompt file `quote_pick.md` — that's fine, but don't edit `news_summary.md` or anything else under prompts/.)
- A parallel worker (`shopping-urgency-element`) is editing `Sarvis/UI/Composer/ElementRegistry.swift` — don't touch it.
- `SarvisApp.swift` edits must be additive — preserve `ElementRegistry.shared.registerBuiltIns()`.
- Don't request user notification permission here; the existing `NotificationService` setup already handles that.
