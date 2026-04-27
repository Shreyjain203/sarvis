# news-rss worker output

## What changed

### New file
- `Sarvis/Services/News/RssProvider.swift` — implements `NewsProvider` protocol using `Foundation.XMLParser`. Fetches `https://news.google.com/rss/search?q=<topic>&hl=en-US&gl=US&ceid=US:en`. Topic is read from `UserDefaults` under key `sarvis_news_topic` (defaults to `"top news"`). Parses RFC 2822 pub-dates, strips the ` - Source Name` suffix that Google News appends to titles, and maps to the existing `NewsArticle` shape. Respects the `limit` parameter via `.prefix(limit)`.

### Modified files
- `Sarvis/Services/News/NewsService.swift` — `init` default provider changed from `GNewsProvider()` to `RssProvider()`.
- `Sarvis/Services/News/GNewsProvider.swift` — one-line deprecation comment added at top; file left on disk for reference.
- `Sarvis/Screens/SettingsView.swift` — GNews API key card removed; replaced with a "News topic" card (plain `TextField`, save/reset buttons, persists to `UserDefaults`). `@State var gnewsKey` removed; replaced with `@State var newsTopic`. `saveGNewsKey()` replaced with `saveNewsTopic()`.
- `docs/phase-2.md` — §2.1 heading updated to show shipped status; scope items converted to a checked list; deferred items noted.
- `STATE.md` — 2026-04-27 update-log entry appended.

## Surprising / notable
- `project.yml` did not need changes — the `path: Sarvis` source glob picks up `RssProvider.swift` automatically. `xcodegen generate` ran clean; `xcodebuild` produced **BUILD SUCCEEDED** with no warnings in the news path.
- Google News RSS titles include ` - Source Name` as a suffix. `RssProvider` splits on the last ` - ` separator, so `NewsArticle.source` is populated even if the `<source>` XML element is empty.
- The `country` parameter on `NewsProvider.fetchTopHeadlines(country:limit:)` is mapped to the `gl=` and `ceid=` query params (uppercased), so the existing `NewsService.refreshToday(country: "us")` call routes correctly without signature changes.

## Follow-ups / not done
- Direct source feed basket (BBC, Reuters, NPR) — explicitly deferred per spec.
- Per-topic subscriptions / multiple topics — deferred.
- The `NewsService` `### News` section in `STATE.md` still says "GNewsProvider against gnews.io" — could be cleaned up in a later housekeeping pass; didn't touch it to avoid conflicting with the widget-relaunch worker's concurrent STATE.md edits.
