# nav-docs output

## Summary

| Doc | Lines | Areas covered |
|---|---|---|
| docs/codemap.md | ~120 | All 3 targets: Sarvis/ (App, Models, Services/*, UI/*, Screens/), SarvisWidget/, SarvisNotificationContent/ |
| docs/api-surface.md | ~170 | Storage (RawStore, TodoStore, ProfileStore, DailyArtifactStore, NewsCache, EmailCache, KeychainService), LLM (LLMService, AnthropicProvider, ClassifierService, PromptLibrary), News (NewsService, RssProvider), Email (GoogleAuth, GmailProvider, EmailDigestService), Notifications+Jobs (NotificationService, MorningJob, QuoteJob, QuoteService), UI Composer (ElementRegistry, ScreenState, ScreenDefinition, DynamicScreen), Models table |

## Deliberately omitted
- Everything already in STATE.md / phase-1.md / phase-2.md (architecture decisions, phase scope, build status, data-flow narrative)
- Private helpers, init bodies, Codable boilerplate
- UI rules section (already in STATE.md)
- GNewsProvider (deprecated, not referenced by NewsService)
- InputProcessor.swift (no-op stub, not wired)
- Worker dispatch history (already in STATE.md)

## Spot-checks (10/10 pass)

From codemap.md:
1. `RawStore.setNotificationID(for:_:)` — confirmed at RawStore.swift:47 ✓
2. `NewsService.refreshToday(country:limit:)` signature — confirmed at NewsService.swift:19 ✓
3. `RssProvider.topicDefaultsKey = "sarvis_news_topic"` — confirmed at RssProvider.swift:8 ✓
4. `ElementRegistry.registerBuiltIns()` — confirmed at ElementRegistry.swift:35 ✓
5. `MorningJob.taskID = "com.shrey.sarvis.morning"` — confirmed at MorningJob.swift:18 ✓

From api-surface.md:
6. `ClassifierService.classifyUnprocessed() async throws -> ClassifierReport` — confirmed at ClassifierService.swift:101 ✓
7. `GoogleAuth.shared.authorize() async throws` — confirmed at GoogleAuth.swift:93 ✓
8. `QuoteJob.scheduleDailyPings()` (static) — confirmed at QuoteJob.swift:21 ✓
9. `NotificationService.categoryTaskReminder = "task.reminder"` — confirmed at NotificationService.swift:14 ✓
10. `EmailDigestService.shared.todaysDigest() -> EmailDigest?` — confirmed at EmailDigestService.swift:43 ✓
