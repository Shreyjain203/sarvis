# Sarvis

**Your personal AI OS, on iOS.**

Sarvis takes messy, unstructured input — anything you'd jot in Notes or mutter to yourself — and turns it into structured behavior intelligence: todos, notes, shopping, diary, news summaries, motivational nudges, and an inferred profile of you. You capture freely; an LLM classifies, normalizes, and surfaces what matters via a Library tab and notifications.

> **Status:** Phase 1 complete (`v0.1.0`, 2026-04-27). Phase 2 (premium upgrade) in planning.

## Core idea

```
Messy input → fetch external context (offline) → Claude → structured JSON → render
```

The LLM is a **transformer**, not a fetcher. We pull context (news, email subjects, etc.) ourselves, package it cleanly, and only then call Claude to summarize, classify, or normalize. Raw input is never discarded — every capture lands in `Documents/raw/<uuid>.json` and is always re-processable.

## Quickstart

Requirements: Xcode 17, iOS 17+ device or simulator, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), an Anthropic API key.

```bash
# regenerate the Xcode project from project.yml
xcodegen generate

# open + run
open Sarvis.xcodeproj
```

On first launch, paste your **Anthropic API key** in Settings (stored in Keychain — never in source or UserDefaults). Optional: paste a **GNews API key** if you want the news fetch path active during Phase 1; Phase 2 replaces this with RSS.

For prompt changes, edit files in `/prompts/` and sync them into the bundle:

```bash
./tools/sync-prompts.sh
```

## Documentation

- [`STATE.md`](./STATE.md) — **read this first if a conversation drops.** Living snapshot of what's built, the architecture map, public API contracts, UI rules, dispatched workers, and a dated update log.
- [`docs/phase-1.md`](./docs/phase-1.md) — Phase 1 plan + what shipped. Frozen at the `v0.1.0` tag.
- [`docs/phase-2.md`](./docs/phase-2.md) — Phase 2 plan: Gmail integration, durable RSS news source, custom notification UI, widget re-enable.
- [`prompts/`](./prompts/) — LLM prompts (source of truth). Bundled mirror lives at `Sarvis/Resources/Prompts/`.
- [`.dispatch/tasks/<id>/`](./.dispatch/tasks/) — historical worker plan + output records.

## Phases

| Phase | Tag | Status | Scope |
|---|---|---|---|
| Phase 1 — Foundation | `v0.1.0` | ✅ shipped 2026-04-27 | Capture → classify → render pipeline; Library; Todo tiled timeline + completed history; classifier debug viewer; morning + quote jobs; app icon. |
| Phase 2 — Premium upgrade | `v0.2.0` *(planned)* | ⏳ planning | Gmail integration; durable RSS news source; custom notification UI; widget re-enable. |

## Repository layout

```
Sarvis/                  iOS host app
  App/                   SarvisApp (entry, BG task registration), RootView
  Models/                TodoItem, RawEntry, InputType, ScreenDefinition, ...
  Services/
    LLM/                 Anthropic provider, ClassifierService, PromptLibrary
    Storage/             RawStore, ProfileStore, DailyArtifactStore
    News/                GNewsProvider, NewsCache, NewsService
    Quotes/              QuoteService
    Jobs/                MorningJob, QuoteJob
    NotificationService.swift, KeychainService.swift
  UI/
    Theme.swift          design tokens, palette, themed cards, haptics
    Composer/            dynamic UI: ElementRegistry, ScreenState, DynamicScreen
    Elements/Input/      TextInput, CalendarPicker, TypeChip, ImportancePicker, ...
    Elements/Display/    SummaryCard, TodoListRow, NotesListRow, ShoppingListRow, ...
  Screens/               Capture, Today, Library (ProcessedView), Settings, Edit sheets
  Resources/
    Prompts/             bundled mirror of /prompts
    Quotes/              seed.json
    Assets.xcassets/     app icon
SarvisWidget/            WidgetKit extension (currently disabled — see docs/phase-2.md)
prompts/                 source-of-truth LLM prompts
docs/                    phase plans + design notes
.dispatch/tasks/         worker plan + output history
tools/                   sync-prompts.sh and other dev tooling
project.yml              XcodeGen spec
```

## Conventions

- **Theme tokens are the source of truth.** Never hardcode colors, radii, or spacing. Use `Theme.Spacing`, `Theme.Radius`, `Theme.Typography`, `Theme.Palette`. See [`STATE.md` → UI rules](./STATE.md#ui-rules).
- **LLM is for transforms only** — summarizing, normalizing, classifying. **Never** as a search engine or data fetcher.
- **No third-party deps.** Apple frameworks + Anthropic Claude API only.
- **Raw and processed stay separate.** Captures persist as raw JSON; processed buckets are derived and rebuildable.
- **Cache aggressively.** Free API quotas are tight; LLM cost compounds fast.
- **Commit freely; push on milestones.** A tagged release, a wave done, or an explicit ask.

## Reality checks

**iOS background execution is not guaranteed.** `BGAppRefreshTask` is best-effort — iOS throttles based on battery, usage patterns, and its own mood. Always refresh on foreground; don't design a feature that breaks if background tasks skip.

**Free API quotas are tight.** GNews free tier is 100 req/day. Phase 2 moves news to RSS specifically to escape this.

**Claude API cost compounds.** A single daily summary call is cheap; firing a full behavior-layer prompt on every background task spikes spend. Gate LLM calls.

**Gmail OAuth is genuinely annoying.** Cloud Console setup, OAuth consent screen, redirect URIs — budget setup time. We're avoiding the Google SDK by going native (`ASWebAuthenticationSession` + URLSession + Keychain refresh tokens).

**WidgetKit cannot host a live keyboard.** The widget's "text field" is a tappable lookalike that deep-links into the app's `QuickCaptureSheet`. There is no workaround.

## Tech stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI (iOS 17+) |
| Background jobs | BackgroundTasks (`BGAppRefreshTask`) |
| Notifications | `UNUserNotificationCenter` (Phase 2: + Notification Content Extension) |
| Widget | WidgetKit |
| LLM | Anthropic Claude API (`claude-opus-4-7` default) |
| Secrets | Keychain |
| Networking | URLSession |
| Storage | FileManager (JSON) |
| Build | XcodeGen → Xcode 17 |
