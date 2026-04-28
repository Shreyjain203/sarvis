# Phase 2.2 — Gmail integration (native OAuth)

Native OAuth via `ASWebAuthenticationSession` + URLSession + Gmail REST. No GoogleSignIn-iOS SDK. Morning-only fetch cadence. Spec: `docs/phase-2.md` §2.2.

- [x] Read `docs/phase-2.md` §2.2, `Sarvis/Services/KeychainService.swift`, `Sarvis/Services/Jobs/MorningJob.swift`, `Sarvis/Services/News/NewsService.swift` (as the analogue for the new email service), `Sarvis/Services/LLM/ClassifierService.swift` (for the existing prompt-loading + LLM-call pattern), `Sarvis/Screens/SettingsView.swift`, and the Library tab's `ProcessedView.swift`. Understand existing patterns before creating new files
- [x] Define `EmailProvider` protocol + `EmailItem` model in `Sarvis/Models/EmailItem.swift` (`id`, `threadID`, `subject`, `sender`, `snippet`, `receivedAt`)
- [x] Implement `Sarvis/Services/Email/GoogleAuth.swift`:
  - `ASWebAuthenticationSession`-based authorize flow (callback URL scheme = the reverse-domain of the OAuth iOS client ID; e.g., `com.googleusercontent.apps.<suffix>`)
  - PKCE code verifier + challenge (S256), state nonce, scope `https://www.googleapis.com/auth/gmail.readonly`
  - Token exchange: POST `https://oauth2.googleapis.com/token` with `code`, `client_id`, `code_verifier`, `redirect_uri`, `grant_type=authorization_code`
  - Refresh: POST same endpoint with `refresh_token`, `client_id`, `grant_type=refresh_token`
  - Store refresh token in Keychain under `gmail_refresh_token`; access token in memory only with expiry timestamp
  - `connectedEmail()` helper: fetch `https://www.googleapis.com/oauth2/v2/userinfo` to display "Connected as <email>" in Settings (requires adding `email` and `profile` scopes — add them)
  - Public surface: `authorize() async throws -> Void`, `accessToken() async throws -> String` (refreshes if expired), `disconnect()`, `isConnected: Bool`, `email: String?`
- [x] Implement `Sarvis/Services/Email/GmailProvider.swift`:
  - Conforms to `EmailProvider`
  - `fetchRecent(limit:since:) async throws -> [EmailItem]`
  - Two-call pattern: `users.messages.list?q=newer_than:1d&maxResults=<limit>` → array of message IDs; then for each ID, `users.messages.get?id=<id>&format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date`. Pull `snippet` from the metadata response too. Default `since` to "newer_than:1d" if nil
  - Use `GoogleAuth.shared.accessToken()` for Authorization header
  - Auth failure (401): refresh once, retry once; surface error after that
- [x] Implement `Sarvis/Services/Email/EmailCache.swift`:
  - Mirrors `NewsCache`: writes `Documents/cache/email/<YYYY-MM-DD>.json` atomically
  - `loadToday() -> [EmailItem]?` and `saveToday([EmailItem])` API
- [x] Implement `Sarvis/Services/Email/EmailDigestService.swift`:
  - `refreshToday() async throws` orchestration: fetch via provider → cache → call LLM with `prompts/email_classify.md` → write classified output to `Documents/processed/email/<YYYY-MM-DD>.json`
  - Reads bundled prompt via existing `PromptLibrary.body(for:)` pattern
- [x] Define `EmailDigest` model (`Sarvis/Models/EmailDigest.swift`): `important: [EmailItem]`, `fyi: [EmailItem]`, `promo: [EmailItem]`, `actions: [EmailAction]` where `EmailAction` is `{ text: String, sourceMessageID: String, dueAt: Date? }`
- [x] Create `prompts/email_classify.md` with YAML header (`purpose`, `when_used`, `variables`). Variables: `{{emails}}` (JSON array of EmailItem), `{{profile}}` (existing profile JSON), `{{today}}` (ISO date). Output: strict JSON `{"important": [...ids], "fyi": [...ids], "promo": [...ids], "actions": [{"text", "sourceMessageID", "dueAt"}]}`. Mirror tone + structure of `prompts/capture_classify.md` so the slicing parser already handles it. Run `tools/sync-prompts.sh` afterwards to mirror into the bundle
- [x] Wire `MorningJob` to call `EmailDigestService.refreshToday()` after the existing news refresh. Wrap in `try?` so an email failure doesn't kill the news path. Notification copy unchanged ("Today's briefing") but body can append "X important emails" if digest succeeded
- [x] Add Library tab → Email section in `ProcessedView.swift`. Section chip "Email". List today's `important` items first, then `actions`. Use the same visual idiom as Notes/Shopping rows (`themedCard`, palette dots). Tap a row → expand to show snippet + sender
- [x] Update `SettingsView.swift`: replace any old Gmail placeholder (if present) with a "Connect Gmail" row. If `GoogleAuth.isConnected`, show "Connected as <email>" with a "Disconnect" button. The OAuth client ID is required to make this work end-to-end — store it in `Info.plist` under a key like `GoogleOAuthClientID` (read via `Bundle.main.infoDictionary`); add the key to `project.yml` `Info.plist` as `GoogleOAuthClientID: $(GOOGLE_OAUTH_CLIENT_ID)` and document it in `docs/phase-2.md` §2.2 setup section. **Do NOT hard-code a client ID** — the user will paste theirs after Google Cloud Console setup
- [x] Add the iOS URL scheme reverse-domain placeholder to `project.yml` `Info.plist` `CFBundleURLTypes` so the OAuth callback can land. Use `$(GOOGLE_OAUTH_REVERSE_CLIENT_ID)` and document the manual setup step in `docs/phase-2.md`
- [x] Run `xcodegen generate` and `xcodebuild -scheme Sarvis -destination "generic/platform=iOS Simulator" -configuration Debug build`. Confirm BUILD SUCCEEDED. The OAuth flow itself can't be tested without a real client ID — that's expected. Build success means the wiring compiles
- [x] Update `STATE.md` update-log: append a 2026-04-27 entry "Phase 2.2 — Gmail integration shipped (native OAuth via ASWebAuthenticationSession + Gmail REST; morning-only fetch; classified digest; Library → Email section). Requires user to provide OAuth client ID before runtime."
- [x] In `docs/phase-2.md` §2.2, mark scope items as shipped and add a small "User setup checklist" subsection listing the manual Google Cloud Console steps + where to paste the client ID + reverse client ID
- [x] Write summary (files added, the manual setup the user must complete in Google Cloud Console, OAuth scope list, prompt contract, anything surprising) to `.dispatch/tasks/gmail-integration/output.md`
- [x] `touch .dispatch/tasks/gmail-integration/ipc/.done`
  <!-- Items 9–14 completed by gmail-finish worker on 2026-04-27. -->
