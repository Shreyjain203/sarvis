# Phase 2 — Premium upgrade

> **Tag (planned):** `v0.2.0` · **Status:** ⏳ planning, not yet started
>
> Phase 2 takes Sarvis from "working foundation" to something that feels premium. Four workstreams: email, news, notifications, widget. Each is independently deployable; pick order based on appetite.

## Goals

1. **Email integration (Gmail)** — pull Gmail subjects, classify into important / FYI / promo, surface action items.
2. **Durable news source (RSS)** — replace `GNewsProvider`'s rate-limited free tier with RSS feeds. Long-lasting, free, no auth.
3. **Custom notification UI** — make notifications stop looking stock. Notification Content Extension with a SwiftUI-rendered body.
4. **Widget re-enable** — bring `SarvisWidget` back online; resize to `systemLarge`; strip to a big text-field-shaped tap target + Submit pill that deep-links into capture.

## Guiding principles (carry forward from Phase 1)

- **LLM is for transforms only.** Summarize, normalize, classify. Never search, never fetch.
- **No third-party deps.** Apple frameworks + URLSession + Anthropic. Skip Google's Gmail SDK; do OAuth natively.
- **Cheap and long-lasting beats clever.** RSS over paid news APIs. Native OAuth over a third-party SDK that may break with each Google rollout.
- **Cache everything.** LLM calls compound; free quotas are tight.

---

## 2.1 Durable news source (RSS) — ✅ shipped 2026-04-27

### Decision

Replace `GNewsProvider` with `RssProvider`. Two source modes:

- **Google News RSS** — `https://news.google.com/rss/search?q=<topic>&hl=en-US&gl=US&ceid=US:en`. Topic-flexible, no key, durable. **Shipped.**
- **Direct source feeds** — small basket of trusted RSS endpoints (BBC World, Reuters Top, NPR, Hacker News). User-configurable later. (deferred)

### Why

| Option | Free | Durable | No auth | No rate limit | Pick? |
|---|---|---|---|---|---|
| GNews / NewsAPI free tier | ✅ | ⚠️ | needs key | 100/day | ❌ |
| Web scrape Google News HTML | ✅ | ❌ (breaks) | ✅ | ⚠️ | ❌ |
| **RSS (Google News + sources)** | ✅ | ✅ | ✅ | ✅ | ✅ |

RSS has been around since 1999. It will outlive every API on this list.

### Tradeoff

RSS exposes headlines + summaries + source URLs, **not full article bodies**. That's fine — the LLM job is summarizing what's already in the feed, not reading deep articles.

### Scope — shipped

- [x] New `Sarvis/Services/News/RssProvider.swift` — implements `NewsProvider` protocol via `Foundation.XMLParser`.
- [x] `GNewsProvider` wiring in `NewsService.shared` replaced with `RssProvider` (default provider updated).
- [x] `NewsCache` write path unchanged (`Documents/cache/news/<date>.json`).
- [x] `prompts/news_summary.md` unchanged — operates on already-fetched articles.
- [x] Settings: GNews API key row removed; replaced with a plain-text topic input field (persisted in `UserDefaults` under `sarvis_news_topic`; defaults to `"top news"`).
- [x] `GNewsProvider.swift` left on disk with a deprecation comment; unreferenced from `NewsService`.

### Out of scope for Phase 2

- Per-topic subscriptions (user-defined search queries) — defer to a later phase if useful.
- Full-article fetching + scraping — explicitly avoided.
- Direct source feed basket (BBC, Reuters, NPR) — deferred to v0.2.x once RSS parser is stable.

---

## 2.2 Email integration (Gmail)

### Decision

Native OAuth 2.0 via `ASWebAuthenticationSession` + URLSession + Gmail REST API. No GoogleSignIn-iOS SDK.

### Why

- **Native OAuth** keeps the "no third-party deps" rule.
- **Gmail API** is generous (1B quota units/day; ~5 units to list a message ID, ~5 to fetch metadata) — far above any reasonable per-user load.
- **App passwords / IMAP** is being squeezed by Google for non-2FA users; OAuth is the durable path.

### Tradeoff

One-time setup pain in Google Cloud Console (OAuth client, consent screen, redirect URIs). Refresh token storage in Keychain. ~30 min of clicking once, then it's done forever.

### Setup checklist (one-time, manual by user)

- [ ] Create a Google Cloud project (or reuse one).
- [ ] Enable the Gmail API.
- [ ] Create an OAuth 2.0 client (iOS app type), record client ID.
- [ ] Configure the OAuth consent screen (internal/external; scopes: `https://www.googleapis.com/auth/gmail.readonly`).
- [ ] Add the iOS URL scheme reverse-domain (`com.googleusercontent.apps.<client-id-suffix>`) to `project.yml` `Info.plist` keys.

### Scope

- New service layer:
  - `Sarvis/Services/Email/GoogleAuth.swift` — handles auth flow via `ASWebAuthenticationSession`, exchanges auth code for access + refresh tokens, refreshes on 401.
  - `Sarvis/Services/Email/GmailProvider.swift` — implements `EmailProvider` protocol (`fetchRecent(limit:since:)`).
  - `Sarvis/Services/Email/EmailCache.swift` — writes `Documents/cache/email/<date>.json` (subjects + sender + snippet + threadID).
- Token storage: refresh token in Keychain under `gmail_refresh_token`; access token kept in memory.
- New `EmailItem` model with `subject`, `sender`, `snippet`, `receivedAt`, `threadID`.
- New prompt `prompts/email_classify.md` — classifies a batch of email items into `important / fyi / promo` with optional extracted action items.
- New artifact `Documents/processed/email/<date>.json` — `EmailDigest` with classified buckets and action items.
- Library tab: new **Email** section showing today's important + extracted actions.
- Background: `MorningJob` extended to fetch + classify emails (or a new `EmailDigestJob` if cleanly separable).
- Settings: "Connect Gmail" row → triggers OAuth flow → "Connected as <email>" + disconnect button.

### Privacy posture

- **Read-only scope** (`gmail.readonly`).
- We process subjects + sender + 200-char snippet only. No full bodies.
- Email cache is local-only; never sent anywhere except to Claude for summarization (and even then, only the metadata above).
- Disconnect = delete refresh token from Keychain + clear local email cache.

### Out of scope for Phase 2

- Sending email, replying, labeling, archiving — all needs broader scopes and is a different product surface.
- Multi-account support — single Gmail account for now.

---

## 2.3 Custom notification UI

### Decision

Add a **Notification Content Extension** (`UNNotificationContentExtension`) that renders a custom SwiftUI view when the user expands a notification (long-press / pull down). Optionally add a **Notification Service Extension** to attach images at delivery time.

### Why

iOS notifications are limited to title + subtitle + body + an optional attachment image without an extension. To use serif typography, theme tokens, importance dots, custom layout, or rich content, you need an extension target with a custom view controller.

### Tradeoff

Another extension target = another codesign surface (we already hit issues with the widget). Plan to debug provisioning early so we don't lose a day to it later.

### Scope

- New extension target `SarvisNotificationContent/` in `project.yml`.
  - Bundle ID: `com.shrey.sarvis.notification-content`
  - `UNNotificationExtensionCategory` keyed to a category string we register on each scheduled notification (e.g., `task.reminder`, `news.briefing`, `quote.morning`).
  - `UNNotificationExtensionInitialContentSizeRatio` ≈ `1.0`.
- SwiftUI view hosted via `UIHostingController` inside the extension's view controller.
- Visual: serif headline, theme-tokenized palette, importance dot, due-time chip, optional attachment thumbnail.
- Three category templates initially:
  - **Task reminder** — title, body, importance dot, due time.
  - **Morning briefing** — date, headline summary, 2–3 bullet headlines.
  - **Quote** — quote body in serif, attribution, soft accent.
- `NotificationService.schedule(...)` updated to set `UNMutableNotificationContent.categoryIdentifier` per type.
- Optional: `SarvisNotificationService/` extension that runs `UNNotificationServiceExtension.didReceive(_:withContentHandler:)` to attach a thumbnail image (e.g., for news articles with hero images). Defer to v0.2.x if not strictly needed.

### Out of scope for Phase 2

- Interactive widgets inside notifications (iOS 16+ does this with `WidgetKit` integration but is brittle).
- Live activities / Dynamic Island — separate scope.

---

## 2.4 Widget re-enable

### Decision

Bring `SarvisWidget` back online. Single family: `systemLarge`. Strip everything down to **a big text-field-shaped tap target + a Submit pill**. Tapping the widget deep-links into the host app via `sarvis://capture`, which presents the existing `QuickCaptureSheet` with the keyboard already focused.

### Why

User wants a frictionless "open and type" surface from the home screen.

### The fundamental constraint

**WidgetKit cannot host a live keyboard or text input.** This is an Apple platform restriction; there is no workaround. The widget shows a *visual* text field; actual typing happens in the app.

### Scope

- Re-enable in `project.yml`:
  - Uncomment the `SarvisWidget` target block.
  - Restore the `dependencies:` entry on the `Sarvis` target.
- Fix the codesign issue that disabled it on physical iPhone:
  - Verify both targets share the same `DEVELOPMENT_TEAM`.
  - Confirm the widget bundle ID is registered as a separate App ID in the Apple Developer portal under the same team, with a matching provisioning profile.
- Trim `SarvisWidget/View.swift`:
  - Remove `systemSmall` and `systemMedium` providers; declare `systemLarge` only.
  - Layout: large rounded-rect "What's on your mind?" placeholder taking ~60% of widget height + a wide Submit pill at the bottom. Both are the same `Link(destination: URL(string: "sarvis://capture")!)` target so any tap dispatches the deep link.
  - Use theme tokens for colors and radii (mirror `WidgetTheme` from Phase 1).
- Host app: deep-link handler in `RootView.onOpenURL` already exists from Phase 1; no change needed.

### Out of scope for Phase 2

- Lock screen widgets (`accessoryRectangular`, `accessoryCircular`) — defer.
- Configurable widget content via App Intents — defer.
- Multi-size support — explicitly out per user direction.

---

## Cross-cutting concerns

### Migration / data compatibility

- Existing `Documents/cache/news/<date>.json` files written by `GNewsProvider` decode into the same `NewsArticle` shape — no migration needed.
- New `Documents/processed/email/<date>.json` is additive; no impact on existing buckets.
- Notification category identifiers are new; existing scheduled notifications without a category fall back to the default body and are still delivered.

### Build + signing

- Two new targets (notification content extension, optionally notification service extension). Each needs:
  - A unique bundle ID under `com.shrey.sarvis.*`.
  - An entry in the host app's "Embed Foundation Extensions" build phase (XcodeGen handles this via `dependencies:` with `embed: true`).
  - A provisioning profile under the same `DEVELOPMENT_TEAM`.
- Re-enabling `SarvisWidget` adds back a third extension target. Sanity-check codesign on a physical device early — this was the Phase 1 blocker.

### Telemetry / debugging

- Reuse the `ClassifierDebugRecord` pattern: capture every email-classification round and surface in Settings → Debug for inspection.
- Log RSS parse failures + Gmail token refreshes to a small in-memory ring buffer accessible from Settings → Debug.

### Open questions

- **News:** start with Google News RSS only, or ship with a 3-source basket (BBC + Reuters + NPR)? Recommendation: start single-source (Google News with a `q=` topic) and add the basket once the parser is stable.
- **Email:** poll cadence — once at morning job, or every 2–4 hours? Recommendation: morning-job-only for v0.2.0; add a manual "Refresh email" button in Library → Email if the user wants more.
- **Notifications:** ship category templates one at a time (start with task reminder), or all three at once?
- **Widget:** keep `systemSmall` / `systemMedium` as compatibility stubs that show "Open Sarvis" buttons, or remove entirely? User said "size should be big and nothing else" — interpreting as remove entirely.

## Order of work

Not yet decided. Three reasonable orderings:

1. **Lowest risk first:** RSS news → notifications UI → widget re-enable → Gmail.
2. **Highest user impact first:** notifications UI → widget re-enable → Gmail → RSS news.
3. **Greenfield-first:** Gmail (biggest new surface) → RSS news → notifications UI → widget re-enable.

User picks at kickoff.

## Definition of done for `v0.2.0`

- [ ] News fetched via RSS; GNews provider removed or marked deprecated.
- [ ] Gmail OAuth flow working end-to-end on a physical device; email digest generated and visible in Library → Email.
- [ ] At least one notification category renders via the custom content extension on a physical device.
- [x] Widget re-enabled (`systemLarge` only), codesign config cleaned, deep-link to `QuickCaptureSheet` verified. `xcodegen generate` clean. Physical-device codesign to be confirmed on first device build.
- [ ] `STATE.md` update-log entry for each shipped item.
- [ ] `docs/phase-2.md` updated to retrospective tone (mirror `phase-1.md`).
- [ ] Tag `v0.2.0` and push.
