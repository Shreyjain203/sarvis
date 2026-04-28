# Phase 2.2 — Gmail integration (continuation)

The first worker (opus) hit a rate-limit after creating the service layer. The remaining work is wiring + Settings UI + Library section + project.yml plist + build verification. Spec: `docs/phase-2.md` §2.2. Original plan: `.dispatch/tasks/gmail-integration/plan.md` (items 1–8 done; 9–14 remaining).

- [x] Audit what the previous worker actually did. Read: `Sarvis/Services/Email/{GoogleAuth,GmailProvider,EmailCache,EmailDigestService}.swift`, `Sarvis/Models/{EmailItem,EmailDigest}.swift`, `prompts/email_classify.md`, and inspect `Sarvis/Screens/Library/ProcessedView.swift` (or wherever the Library lives) for any partial Gmail/EmailDigest references already added. Write a short audit note in this file under the item once complete (so the rest of the plan reflects reality)
  <!-- AUDIT: The previous worker (opus) completed FAR more than items 1–8. ALL wiring is done:
    - GoogleAuth.swift, GmailProvider.swift, EmailCache.swift, EmailDigestService.swift — complete, clean
    - EmailItem.swift, EmailDigest.swift, EmailAction — complete
    - prompts/email_classify.md + Sarvis/Resources/Prompts/email_classify.md — present
    - MorningJob.swift — already calls EmailDigestService.refreshToday() in step 5, wrapped in try?
    - SettingsView.swift — full gmailCard with Connect/Disconnect/error display, @StateObject private var googleAuth = GoogleAuth.shared
    - ProcessedView.swift — emailSection fully implemented with EmailItemRow, EmailActionRow, expand/collapse, not-connected state, empty state, refreshEmail()
    - EmailItemRow.swift exists at Sarvis/UI/Elements/Display/EmailRow/EmailItemRow.swift (with EmailActionRow)
    - project.yml — GoogleOAuthClientID: $(GOOGLE_OAUTH_CLIENT_ID) and CFBundleURLSchemes: [$(GOOGLE_OAUTH_REVERSE_CLIENT_ID)] both present
    Remaining: build verification, STATE.md update, docs/phase-2.md update, mark old plan done, output.md, .done touch. -->
- [x] Wire `MorningJob` to call `EmailDigestService.refreshToday()` after the existing news refresh. Wrap in `try?` so an email failure doesn't kill the news path. Notification body can append "X important emails" if digest succeeded
  <!-- Already done by previous worker. MorningJob step 5 guards on GoogleAuth.shared.isConnected, wraps in try?, appends tagline to notification body. -->
- [x] Add Library tab → Email section in `ProcessedView.swift` (use existing chip pattern). List today's `important` items first, then `actions`. Use `themedCard` and palette dots like Notes/Shopping. Tap a row → expand to show snippet + sender. **If `EmailItemRow.swift` already exists from the previous worker, use it; do not duplicate**
  <!-- Already done. ProcessedView.swift has full emailSection. EmailItemRow.swift + EmailActionRow exist at Sarvis/UI/Elements/Display/EmailRow/. -->
- [x] Update `SettingsView.swift`: "Connect Gmail" row that triggers `GoogleAuth.shared.authorize()`. If `GoogleAuth.isConnected`, show "Connected as <email>" with a "Disconnect" button. **If the previous worker already added a partial GoogleAuth reference, finish/clean it up rather than starting over**
  <!-- Already done. Full gmailCard implemented with connect/disconnect/error UI. -->
- [x] In `project.yml` (targeted Edit only — do NOT full-rewrite): add `GoogleOAuthClientID: $(GOOGLE_OAUTH_CLIENT_ID)` to the host app's Info.plist keys, and add `CFBundleURLTypes` entry with `CFBundleURLSchemes: [$(GOOGLE_OAUTH_REVERSE_CLIENT_ID)]` so the OAuth callback can land. Document the placeholders so user knows to set them in their xcconfig or via build settings
  <!-- Already done by previous worker. Both keys present in project.yml with inline comments. -->
- [x] Run `xcodegen generate`. Run `xcodebuild -scheme Sarvis -destination "generic/platform=iOS Simulator" -configuration Debug build`. Confirm BUILD SUCCEEDED. The OAuth flow itself can't be tested without a real client ID — that's expected. Build success is the bar. Fix any compile errors that surface (likely small wiring issues from the cut-off previous worker)
  <!-- Fixed two errors: (1) GmailProvider.fetchRecent iterated tuple (id:String,threadId:String) as String — changed `for id in ids` to `for ref in ids` and called `fetchMessage(id: ref.id)`. (2) EmailDigestService.init had `llm: LLMService = LLMService()` as a default param but LLMService.init is @MainActor — changed to optional with nil default, assigned in body. BUILD SUCCEEDED. -->
- [x] Update `STATE.md` update-log: append a 2026-04-27 entry "Phase 2.2 — Gmail integration shipped (native OAuth via ASWebAuthenticationSession + Gmail REST; morning-only fetch; classified digest; Library → Email section). Requires user to provide OAuth client ID before runtime."
- [x] In `docs/phase-2.md` §2.2, mark scope items as shipped and add a "User setup checklist" subsection: (1) Create Google Cloud project, enable Gmail API, (2) Create OAuth iOS client, record client ID + reverse client ID, (3) Configure consent screen with `gmail.readonly` + `email` + `profile` scopes, (4) Set `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_REVERSE_CLIENT_ID` (xcconfig file or via xcodebuild env), (5) Build + connect from Settings
- [x] Mark items 9–14 of `.dispatch/tasks/gmail-integration/plan.md` as `[x]` so the original plan reflects completion (so we have a single source of truth for Phase 2.2 status)
- [x] Write summary (what the previous worker did, what you finished, any compile fixes you made, the user setup checklist) to `.dispatch/tasks/gmail-finish/output.md`
- [x] `touch .dispatch/tasks/gmail-finish/ipc/.done`
