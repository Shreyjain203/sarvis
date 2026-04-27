# Phase 2.1 — Durable news source (RSS)

Replace `GNewsProvider` with `RssProvider` using single-source Google News RSS. Spec: `docs/phase-2.md` §2.1.

- [x] Read `docs/phase-2.md` §2.1, `Sarvis/Services/News/GNewsProvider.swift`, `NewsService.swift`, `NewsCache.swift`, and the `NewsProvider` protocol to confirm the surface area before changing anything
- [x] Create `Sarvis/Services/News/RssProvider.swift` implementing the `NewsProvider` protocol; parse Google News RSS (`https://news.google.com/rss/search?q=<topic>&hl=en-US&gl=US&ceid=US:en`) with `Foundation.XMLParser` (no third-party deps); map RSS items into the existing `NewsArticle` shape
- [x] Wire `NewsService.shared` to use `RssProvider` instead of `GNewsProvider`; preserve the `NewsCache` write path (`Documents/cache/news/<date>.json`) unchanged
- [x] Update Settings: remove the GNews API key row; replace with a simple topic input (or hard-code a sensible default topic until a settings UX lands)
- [x] Add `RssProvider` to `project.yml` sources if XcodeGen needs it; run `xcodegen generate` and confirm the project builds (no compile errors in the news path) — no explicit entry needed; `path: Sarvis` picks it up; BUILD SUCCEEDED
- [x] Don't delete `GNewsProvider.swift` yet — leave it on disk but unreferenced, so we can compare if RSS misbehaves. Add a one-line comment at the top noting it's deprecated as of v0.2.0
- [x] Update `STATE.md` update-log with a 2026-04-27 entry: "Phase 2.1 — switched news pipeline from GNews to Google News RSS via new `RssProvider`"
- [x] In `docs/phase-2.md` §2.1, mark the items as shipped (or note progress)
- [x] Write summary of what changed (files added/modified, anything surprising, any follow-ups) to `.dispatch/tasks/news-rss/output.md`
- [x] `touch .dispatch/tasks/news-rss/ipc/.done`
