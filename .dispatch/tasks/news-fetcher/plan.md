# News fetcher service

Add a small NewsAPI client + cache + LLM-summarizer plumbing. Pure additive — new files in `Sarvis/Services/News/`. Does NOT wire scheduling or notifications (the morning-job worker handles that later); does NOT call the LLM yet (just stores the raw fetch). The classifier/summarizer LLM call comes in Wave 2.

**API choice:** default to **GNews** (free tier, 100 req/day, no card required). Allow override later. User must paste a GNews API key into Settings → Keychain (same pattern as Anthropic key).

- [x] **Add `Sarvis/Services/News/NewsArticle.swift`:** — created; Identifiable/Codable/Hashable struct with id computed from url.
- [x] **Add `Sarvis/Services/News/NewsProvider.swift`** — protocol + NewsError enum created.
- [x] **Add `Sarvis/Services/News/GNewsProvider.swift`** — concrete impl; reads `gnews_api_key` from Keychain, URLSession GET to GNews v4 endpoint, ISO8601 date decoding, typed error throws.
- [x] **Add `Sarvis/Services/News/NewsCache.swift`:** — atomic writes to `Documents/cache/news/<YYYY-MM-DD>.json`; read/write API implemented.
- [x] **Add `Sarvis/Services/News/NewsService.swift`** — @MainActor singleton with `refreshToday`, `articlesForToday`, `@Published lastError`.
- [x] **Add a Settings hook for the GNews key.** — Added `gnewsKeyCard` view + `gnewsKey` state + `saveGNewsKey()` to `SettingsView.swift`; uses Theme tokens, Save/Clear buttons, toast feedback.
- [x] **Add prompt file `prompts/news_summary.md`** — created with YAML header + `{{articles}}` placeholder; synced to `Sarvis/Resources/Prompts/` via `tools/sync-prompts.sh`.
- [x] **Verification:** `swift -frontend -parse` passed on all 5 new files + modified SettingsView.swift. `xcodegen generate` exited 0.
- [x] Write a summary to `.dispatch/tasks/news-fetcher/output.md` — written.

**Constraints:**
- iOS 17+. `URLSession` only — no third-party deps.
- Don't call the LLM in this worker. Just fetch + cache + Settings UI.
- Don't touch any file under `Sarvis/Models/`, `Sarvis/UI/`, or `Sarvis/Services/Storage/` — those are owned by the parallel `storage-layout-v2` worker.
- The Settings file (`Sarvis/Screens/SettingsView.swift`) is yours to edit; do it minimally — one extra row.
- Do NOT touch `Sarvis/Services/LLM/` — different concern, separate refactor.
- Use `Theme` tokens. No magic numbers in the Settings row.
