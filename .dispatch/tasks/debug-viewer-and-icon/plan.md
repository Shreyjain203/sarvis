# Debug viewer for classifier + new app icon

Two requests bundled — both touch UI/app config so doing them in one worker pass.

## 1. Classifier debug viewer (hidden, toggleable)

Goal: when classification is off, user wants to inspect the raw LLM round (input raws JSON, prompt sent, raw response string, parsed JSON, distribution log, error if any). Surfaced via Settings, not the main UI.

- [x] **Add `ClassifierDebugRecord` model + capture in `ClassifierService`.** New struct (Codable for ease of display): timestamp, input raws (the raws fed in this round), system prompt + user prompt sent, raw LLM response string, parsed `ClassifierResponse?` (or nil if parse failed), per-item distribution log (each entry: raw id → resolved type → "added"/"skipped: reason"), itemsAdded count, error message if thrown. On `ClassifierService`, expose `@Published var lastRun: ClassifierDebugRecord?`. Populate it inside `classifyUnprocessed` — wrap the whole flow so success AND failure both record. Keep it in-memory only (no disk persistence needed; user sees only the most recent run).
- [x] **Build a `ClassifierDebugView` screen.** Sections (use existing Theme tokens, themedCard idiom):
  - Header with timestamp + itemsAdded summary + error banner if present.
  - Input raws — list of `RawEntry` snippets (text, suggestedType, importance).
  - Prompt sent — collapsible monospace block (system + user).
  - Raw LLM response — collapsible monospace block.
  - Parsed JSON — collapsible monospace pretty-printed `ClassifierResponse`.
  - Distribution log — list of "<raw text snippet> → <type> → <action>".
  - Empty state copy: "No classifier run captured yet. Tap Process on the Capture screen with at least one raw entry, then come back."
- [x] **Wire it into Settings.** Add a `Debug` section at the bottom of `SettingsView` (or wherever the existing settings live — read the file first). Single row: "View last classifier run" → NavigationLink to `ClassifierDebugView`. No on/off toggle needed — user said "hidden feature, toggle on/off" but living in Settings already keeps it out of the main flow; a toggle would just be Settings clutter. If there's an obvious `UserDefaults`-backed flag pattern already in use for debug stuff, mirror it. Otherwise leave as a plain Settings row.
- [x] **Build sanity-check.** `xcodebuild -scheme Sarvis -destination 'generic/platform=iOS Simulator' build` → should succeed. Pre-existing `@frozen` warnings are fine. (had to `xcodegen generate` to pick up the new file; build then green.)

## 2. App icon — monkey image

Source image: `~/Downloads/output.jpg` (the only recent image in Downloads — 41K, dated 2026-04-26 18:33). Treat it as the monkey image.

- [x] **Generate iOS app-icon set from `~/Downloads/output.jpg`.** iOS expects a 1024×1024 marketing-size icon (and conventionally a full set of sizes). Use `sips` on macOS to resize. Required sizes for a modern iOS app icon set (`AppIcon.appiconset/Contents.json`):
  - iPhone notification: 40x40 (20pt @2x), 60x60 (20pt @3x)
  - iPhone settings: 58x58 (29pt @2x), 87x87 (29pt @3x)
  - iPhone spotlight: 80x80 (40pt @2x), 120x120 (40pt @3x)
  - iPhone app: 120x120 (60pt @2x), 180x180 (60pt @3x)
  - iPad notification: 20x20 (20pt @1x), 40x40 (20pt @2x)
  - iPad settings: 29x29 (29pt @1x), 58x58 (29pt @2x)
  - iPad spotlight: 40x40 (40pt @1x), 80x80 (40pt @2x)
  - iPad app: 76x76 (76pt @1x), 152x152 (76pt @2x)
  - iPad Pro: 167x167 (83.5pt @2x)
  - Marketing: 1024x1024 (App Store)
  PNGs are required — convert from JPG via sips. iOS app icons must be opaque (no alpha channel).
- [x] **Locate or create `Assets.xcassets/AppIcon.appiconset/`.** Lives at `Sarvis/Resources/Assets.xcassets/AppIcon.appiconset/`. Replaced placeholder Contents.json with full size→filename mapping; project.yml already sets `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. Find the existing Assets catalog (likely `Sarvis/Resources/Assets.xcassets` or similar — confirm by searching). If `AppIcon.appiconset/` already exists, replace its PNGs and update `Contents.json` filenames. If not, create the directory with a fresh `Contents.json` listing each size→filename mapping. project.yml may need an `app_icon` setting if not auto-detected — check its current state.
- [x] **If `project.yml` references the AppIcon, regenerate the project.** Run `xcodegen generate` so `Sarvis.xcodeproj` picks up the new asset set. (Done as part of step 1's build fix.)
- [x] **Build sanity-check.** Same xcodebuild command. Watch for any "no app icon found" warnings — if seen, fix `project.yml` or `Contents.json`. (Build green; only pre-existing `@frozen` warnings; no icon warnings.)

## 3. Wrap-up

- [ ] **One clean commit, no push.** Suggested subject: "Add classifier debug viewer + new app icon (monkey)". Update `STATE.md` with a 2026-04-26 update-log entry.
- [ ] **Write summary to `.dispatch/tasks/debug-viewer-and-icon/output.md`.**

---

**Context:**

- Outcome the user asked for: (1) a hidden/toggleable place to inspect what the LLM returned during classification because results aren't great, used for debugging; (2) replace the app icon with the monkey image in `~/Downloads/output.jpg`.
- Reference files (read first):
  - `Sarvis/Services/LLM/ClassifierService.swift` — where to add `lastRun`. Already has `lastLLMError` precedent.
  - `Sarvis/Screens/InputView.swift` — `runClassifier()` is the call site; the worker only needs to read it for context, no edits.
  - `Sarvis/Screens/SettingsView.swift` (or whichever file holds settings — search `SettingsView` if unsure) — add the Debug section here.
  - `Sarvis/UI/Theme.swift` — design tokens.
  - `STATE.md` — for the update-log entry; also check the "UI rules" section for screen-shell idiom.
  - `project.yml` — for icon config if needed.
- Constraints:
  - Don't push. Commit only.
  - Don't change main UI flow — debug viewer lives behind Settings, not as a fourth tab.
  - No on/off toggle plumbing unless trivial. Settings location is the toggle.
  - Don't touch news/MorningJob code — that's paused, separate concern.
  - Pre-existing SourceKit "Cannot find X in scope" warnings are project-indexing flake — ignore.
- Decision-making: questions written to `ipc/<NNN>.question` won't be picked up mid-run (no monitor). Make best-effort decisions yourself. Only block with `[!]` on genuinely unresolvable issues.
