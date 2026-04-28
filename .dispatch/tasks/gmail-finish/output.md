# gmail-finish — output

## What the previous worker (opus) did

The previous worker implemented the entire Gmail service layer and all UI wiring before hitting a rate limit. Almost nothing was left to do:

- `Sarvis/Services/Email/GoogleAuth.swift` — complete: ASWebAuthenticationSession + PKCE (S256) + state nonce, token exchange + refresh, Keychain persistence, `disconnect()` with best-effort revoke, `email` published property via userinfo endpoint.
- `Sarvis/Services/Email/GmailProvider.swift` — complete: two-call Gmail REST pattern (list IDs → fetch metadata), snippet truncation, 401 refresh-and-retry.
- `Sarvis/Services/Email/EmailCache.swift` — complete: atomic write to `Documents/cache/email/<date>.json`.
- `Sarvis/Services/Email/EmailDigestService.swift` — complete: fetch → cache → LLM classify → persist to `Documents/processed/email/<date>.json`. `refreshToday()` / `todaysDigest()` surface.
- `Sarvis/Models/EmailItem.swift` + `EmailDigest.swift` — complete.
- `prompts/email_classify.md` + `Sarvis/Resources/Prompts/email_classify.md` — both present.
- `Sarvis/UI/Elements/Display/EmailRow/EmailItemRow.swift` — complete: `EmailItemRow` (tap-to-expand) + `EmailActionRow`.
- `Sarvis/Services/Jobs/MorningJob.swift` — email refresh already wired (step 5, guarded by `isConnected`, wrapped in `try?`, appends tagline to notification body).
- `Sarvis/Screens/ProcessedView.swift` — email section already implemented: not-connected empty state, loading state, digest display (important → actions with expand/collapse), manual refresh.
- `Sarvis/Screens/SettingsView.swift` — Gmail card already complete: connect flow, "Connected as \<email>", disconnect, error display.
- `project.yml` — `GoogleOAuthClientID: $(GOOGLE_OAUTH_CLIENT_ID)` + `CFBundleURLSchemes: [$(GOOGLE_OAUTH_REVERSE_CLIENT_ID)]` already added.

## What this worker (gmail-finish) did

1. **Audited** all files listed above and confirmed they were complete.
2. **Fixed two compile errors:**
   - `GmailProvider.swift` line 30: `for id in ids` iterated a tuple `(id:String, threadId:String)` but passed the tuple directly to `fetchMessage(id:)` which expected a `String`. Fixed: changed loop variable to `ref` and used `ref.id`.
   - `EmailDigestService.swift` line 29: `llm: LLMService = LLMService()` as a default parameter failed because `LLMService.init` is `@MainActor` and default parameter expressions execute in nonisolated context. Fixed: changed to `llm: LLMService? = nil` and assigned `self.llm = llm ?? LLMService()` in the body (the body runs on `@MainActor`).
3. **Ran `xcodegen generate`** — clean.
4. **Ran `xcodebuild` (iOS Simulator, Debug)** — BUILD SUCCEEDED.
5. **Updated `STATE.md`** — appended 2026-04-27 update-log entry.
6. **Updated `docs/phase-2.md` §2.2** — marked shipped, added full user setup checklist subsection.
7. **Marked items 9–14** of `.dispatch/tasks/gmail-integration/plan.md` as `[x]`.

## User setup checklist (must complete before Gmail works at runtime)

1. Create a Google Cloud project; enable the Gmail API.
2. Create an OAuth 2.0 iOS client (bundle ID `com.shrey.sarvis`). Record the client ID (`123-abc.apps.googleusercontent.com`) and reverse client ID (`com.googleusercontent.apps.123-abc`).
3. Configure the OAuth consent screen: scopes `gmail.readonly`, `email`, `profile`. Add your Apple ID email as a test user.
4. Set build settings (xcconfig or Xcode Build Settings):
   ```
   GOOGLE_OAUTH_CLIENT_ID = 123-abc.apps.googleusercontent.com
   GOOGLE_OAUTH_REVERSE_CLIENT_ID = com.googleusercontent.apps.123-abc
   ```
5. Rebuild. Open Settings in app → "Connect Gmail" → sign in.

## Build status

BUILD SUCCEEDED (iOS Simulator, x86_64, Debug). Warnings about Swift 6 `@MainActor` default parameters are warnings only and do not affect functionality.
