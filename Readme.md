# Sarvis

**Your personal AI OS, on iOS.**

Sarvis takes messy, unstructured input from your life — notes, email subjects, location history, screen usage, weather, news — feeds it all into Claude, and produces a structured behavioral picture of your day. It generates todos, surfaces insights, sends smart notifications, and nudges you toward better decisions. Not a notes app. Not a reminder app. A personal decision engine that observes, structures, and acts.

---

## Table of Contents

1. [Core Idea](#core-idea)
2. [Architecture](#architecture)
3. [Dynamic UI](#dynamic-ui)
4. [File & Folder Structure](#file--folder-structure)
5. [Storage Layout](#storage-layout)
6. [Tech Stack](#tech-stack)
7. [MVP Phases](#mvp-phases)
8. [Setup & Build](#setup--build)
9. [Reality Checks](#reality-checks)
10. [Roadmap](#roadmap)

---

## Core Idea

The engine is simple:

```
Messy input + external data → Claude → structured JSON
```

Everything in Sarvis is downstream of that pipeline. You write a raw note. The app fetches weather, news, email subjects, screen time stats, and location context. All of it gets bundled into a single Claude prompt. Claude returns structured JSON. That JSON drives todos, notifications, summaries, and nudges.

Raw input is never discarded — it lives on disk and is always re-processable. The LLM is a formatter and thinker, not a data fetcher. Fetch first, think second.

**Example LLM output:**

```json
{
  "todos": [
    { "task": "Pay rent", "priority": "high" },
    { "task": "Reply to manager email", "priority": "high" }
  ],
  "news_summary": "AI regulations tightening globally.",
  "weather_alerts": ["Heavy rain expected this afternoon"],
  "insights": [
    "You spent 2.5h on Instagram today",
    "You have 2 important unread emails"
  ],
  "nudges": [
    "Take a break from social media",
    "Check your bank statement"
  ],
  "mood": "low"
}
```

---

## Architecture

### 1. Input Layer

Free-form text. No required fields. Write whatever's in your head.

Stored as:

```
/data/raw/YYYY-MM-DD.txt
```

### 2. Data Sources

| Source | API |
|---|---|
| News | NewsAPI or GNews |
| Weather | OpenWeatherMap or WeatherAPI |
| Location | iOS CoreLocation (no external API) |
| Email | Gmail API (OAuth) or IMAP |
| Screen time | FamilyControls + DeviceActivity |

### 3. Scheduler

Three job types:

**Hourly**
- Personal todos refresh
- Weather update (only if location changed or threshold crossed)
- Screen time limit checks → notifications

**Daily (once)**
- News fetch
- Full behavior summary via Claude (~60 words is enough)
- Motivational insights

**On-demand**
- Button tap → pull everything → LLM → display

iOS implementation: `BGAppRefreshTask`. Background execution is not guaranteed — always trigger a refresh on app open as a fallback.

### 4. LLM Processing

```
RAW TEXT + API DATA + EMAIL SUBJECTS + SCREEN TIME + LOCATION
    → Claude API
    → structured JSON
    → /data/processed/YYYY-MM-DD.json
```

Key rules:
- **Don't call APIs inside the LLM prompt.** Fetch first, send clean data.
- **Cache everything.** Protect free-tier limits.
- **Keep raw and structured separate.** That separation is the whole architecture.

### 5. Location Intelligence

Use `CLLocationManager` significant-change mode (not continuous GPS — battery matters).

Logic:
- Track precise for 7 days
- Compress into hotspots (frequent locations + avg duration)

```json
{
  "place": "Office",
  "lat": 37.7749,
  "lng": -122.4194,
  "visits": 5,
  "avg_duration": "3h"
}
```

Stored in `/data/location/`.

Contextual notifications become possible once hotspots are established:
> "You're near the gym — you haven't gone in 4 days."

### 6. Email Integration

Goal: privacy-first. Don't read full email bodies — only subject lines.

Flow:
```
Gmail API / IMAP → subject lines → /data/email/raw.txt
    → Claude → /data/email/processed.json
```

Example input to Claude:
```
"Your bank statement is ready"
"Team meeting rescheduled"
"50% off sale!!!"
```

Example output:
```json
{
  "important": [
    "Your bank statement is ready",
    "Team meeting rescheduled"
  ],
  "ignore": ["50% off sale!!!"],
  "actions": [
    { "task": "Check bank statement", "priority": "high" }
  ]
}
```

Fetch frequency: every 2–4 hours, or on-demand.

### 7. Screen Time Control

Uses `FamilyControls` + `DeviceActivity` framework.

**What you can do:**
- Track per-app usage (Instagram, TikTok, etc.)
- Set daily time limits
- Set time-window rules ("no Instagram after 11 PM")
- Send notifications at 80% / 100% / 120% of limit
- Show Apple's native app shield (user must grant permission)

**What you cannot do:**
- Force-close apps
- Block without explicit user permission
- Anything Apple hasn't blessed

Data model:
```json
{
  "app": "Instagram",
  "daily_limit": "60min",
  "used": "75min",
  "status": "exceeded"
}
```

Notification escalation:
- 80% → warning
- 100% → alert
- 120% → aggressive LLM-generated nudge

### 8. Behavior Intelligence Layer

This is the edge. Combine everything into one Claude call:

```
notes + email subjects + screen usage + location + weather + news
    → Claude
    → behavioral JSON
```

```json
{
  "todos": ["..."],
  "insights": [
    "You spent 2.5h on Instagram today",
    "You have 2 important unread emails"
  ],
  "nudges": [
    "Take a break from social media",
    "Reply to your manager email"
  ],
  "mood": "low"
}
```

### 9. Notification Engine

Four categories:

| Type | Examples |
|---|---|
| System-based | Weather alert, screen time exceeded |
| LLM-based | "You've been unproductive today", "You might be stressed" |
| Scheduled | Daily evening summary |
| Contextual | "You're near the gym — go workout" |

Implementation: `UNUserNotificationCenter`.

---

## Dynamic UI

Sarvis uses a **composer + element registry** model. Screens are data, not hardcoded views.

Each screen is a `ScreenDefinition` — a list of `ElementSpec`s with a type tag, config, and optional binding. A `ScreenComposer` reads the definition and instantiates the matching `SwiftUI` view from a registry. Adding a new element means dropping a folder and registering it — no changes to existing screens.

```swift
struct ScreenDefinition: Codable {
    let id: String
    let title: String
    let elements: [ElementSpec]
}

struct ElementSpec: Codable {
    let type: String        // "TextInput", "CalendarPicker", etc.
    let config: [String: AnyCodable]
    let binding: String?    // key into the screen's state dict
}
```

**Element directory layout:**

```
Sarvis/UI/Elements/
    Input/
        TextInput/
        CalendarPicker/
        TimePicker/
        DurationPicker/
        TypeChip/
        ImportancePicker/
        ToggleRow/
        LocationPicker/
        AudioRecorder/
        AttachmentPicker/
    Display/
        TodoList/
        SummaryCard/
        WeatherCard/
        NewsList/
        InsightCard/
        NudgeBanner/
        MapHotspots/
        ScreenTimeChart/
        EmailList/
        MoodIndicator/
        JSONViewer/
        ActionButton/
```

Each folder contains the `View`, a `Config` struct, and a `register()` call. The registry maps the type string to a view factory. The composer iterates `elements`, looks up the factory, passes config, and stacks the result.

This means the LLM can eventually describe a screen in JSON and the app will render it — no code changes required.

---

## File & Folder Structure

```
Sarvis/                         # main app target (post-rename)
    App/
        SarvisApp.swift
        RootView.swift
    Models/
        InputType.swift
        TodoItem.swift
        TodoStore.swift
    Screens/                    # thin SwiftUI screens (use Composer)
        InputView.swift
        TodayView.swift
        SettingsView.swift
    Services/
        LLM/
            LLMProvider.swift
            AnthropicProvider.swift
            LLMService.swift
            PromptLibrary.swift
        Storage/
            InputProcessor.swift
        NotificationService.swift
        KeychainService.swift
    UI/
        Elements/
            Input/  ...
            Display/ ...
        Theme.swift
        Toast.swift
    Resources/
        Assets.xcassets/
        Prompts/                # bundled prompt templates (synced from /prompts)
    Info.plist

SarvisWidget/                   # WidgetKit target

prompts/                        # source-of-truth prompt files
    basic_app.md
    capture_cleanup.md
    classify_input.md
    daily_update.md
    sensitive_detect.md
    sync-prompts.sh             # copies prompts into app bundle

tools/                          # dev tooling

project.yml                     # xcodegen spec
setup.sh
```

---

## Storage Layout

These paths resolve to the iOS **Documents directory** at runtime — not the repo. They are not committed to source control.

```
{Documents}/data/
    raw/            # YYYY-MM-DD.txt — raw user input, append-only
    processed/      # YYYY-MM-DD.json — LLM-structured output
    email/
        raw.txt     # fetched subject lines
        processed.json
    location/       # location logs + hotspot snapshots
    screen_time/    # DeviceActivity snapshots
    cache/          # API responses (news, weather) — safe to delete
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI (iOS 17+) |
| Location | CoreLocation (significant-change mode) |
| Background jobs | BackgroundTasks (`BGAppRefreshTask`) |
| Notifications | UNUserNotificationCenter |
| Widget | WidgetKit + App Intents |
| Screen time | FamilyControls + DeviceActivity |
| LLM | Anthropic Claude API |
| Secrets | Keychain (never in UserDefaults or source) |
| Networking | URLSession |
| Storage | FileManager (JSON + plaintext) |
| Build | xcodegen → Xcode 17 |

---

## MVP Phases

**Phase 1 — Core engine**
- [ ] Raw text input → save to `/data/raw/`
- [ ] On-demand button → fetch weather + news → send to Claude → display JSON
- [ ] Basic todo list from LLM output

**Phase 2 — Automation**
- [ ] `BGAppRefreshTask` for daily news + weather
- [ ] Processed JSON persisted and displayed on dashboard

**Phase 3 — Notifications + todos**
- [ ] Todo generation wired to `UNUserNotificationCenter`
- [ ] Daily summary notification (evening)
- [ ] LLM-generated nudges

**Phase 4 — Location intelligence**
- [ ] Significant-change location tracking
- [ ] Hotspot compression after 7 days
- [ ] Contextual notifications based on location

**Phase 5 — Email classification**
- [ ] Gmail OAuth or IMAP subject-line fetch
- [ ] LLM classification → important / ignore / action items
- [ ] Email insights folded into daily behavior summary

**Phase 6 — Screen time**
- [ ] DeviceActivity monitoring
- [ ] Usage thresholds + escalating notifications
- [ ] Screen time data merged into behavior layer LLM call

---

## Setup & Build

Requirements: Xcode 17, iOS 17+ device or simulator, Anthropic API key.

```bash
# Clone and install xcodegen if needed
brew install xcodegen

# Generate .xcodeproj and copy prompt files into bundle
./setup.sh

# Open in Xcode
open Sarvis.xcodeproj
```

Add your API key in Settings inside the app — it's stored in Keychain, never in source or `UserDefaults`.

For prompt changes, edit files in `/prompts/` and run:

```bash
./prompts/sync-prompts.sh
```

---

## Reality Checks

**iOS background execution is not guaranteed.** `BGAppRefreshTask` is best-effort — iOS throttles it based on battery, usage patterns, and its own mood. Always refresh on foreground. Don't design a feature that breaks if background tasks skip.

**Location + background + screen tracking = battery pressure.** Use significant-change location (not continuous GPS). Cache API responses aggressively. Screen time monitoring has minimal overhead, but piling it on top of location and background fetch will show up in Battery settings.

**Free API quotas are tight.** NewsAPI free tier is 100 requests/day. Cache news responses and don't re-fetch if the cache is fresh. Weather is more lenient but still cache it.

**Claude API cost compounds fast.** A single daily summary call is cheap. If every background task fires a full behavior-layer prompt, the cost spikes. Gate LLM calls — use cached results where freshness isn't critical.

**Screen time API requires explicit user trust.** FamilyControls entitlement must be approved by Apple. The user must grant "Screen Time" permission manually. You can't silently enable it.

**Gmail OAuth is genuinely annoying.** App review, OAuth consent screen setup, redirect URIs — budget time for it. IMAP is simpler to prototype with but less reliable on modern Google accounts.

---

## Roadmap

- [ ] Dynamic UI composer — build `ScreenComposer`, element registry, and wire existing screens to definitions
- [ ] Widget — surface today's todos and a one-line nudge from the lock screen
- [ ] Email integration — Gmail OAuth + subject classification pipeline
- [ ] Screen time integration — DeviceActivity setup + behavior layer merge
- [ ] Location intelligence — hotspot compression + contextual triggers
- [ ] Prompt tuning — structured output schema enforcement so LLM JSON never breaks the parser
- [ ] Cost controls — token budget per call, fallback to cached output when quota is low
