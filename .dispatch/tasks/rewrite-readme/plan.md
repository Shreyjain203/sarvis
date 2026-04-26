# Rewrite Readme.md for Sarvis

The user has a working draft at `/Users/shrey/Documents/Projects/Reminder app/Readme.md` capturing the long-term vision. Rewrite it as a clean, well-structured README that:
- Renames the project to **Sarvis**.
- Preserves every architectural idea and feature plan the user wrote (raw → LLM → structured JSON, location intel, email subject classification, screen time control, behavior layer, notifications, MVP phasing).
- Adds the new **dynamic UI composition** philosophy (screens are data, elements are plug-ins).
- Reads like a real project README, not a brain-dump. Use clear headings, code fences for JSON / shell, and a TOC if it helps.

- [x] **Read the current `Readme.md`** to capture the full vision (don't drop anything the user wrote — restructure, don't shrink).
- [x] **Rewrite `Readme.md` top to bottom** with this rough structure (adapt as needed):
  - **Title + tagline:** "Sarvis — your personal AI OS, on iOS."
  - **What it is** (one-paragraph elevator pitch — messy input → structured behavior intelligence).
  - **Core idea** (the "messy input → LLM → structured JSON" engine).
  - **Architecture** (Input layer · Data sources · Scheduler · LLM processing · Storage · Location · Notifications · Email · Screen time · Behavior layer). Keep the user's diagrams and JSON examples.
  - **Dynamic UI** — explain the Composer + element registry model. Each screen = a `ScreenDefinition` of `ElementSpec`s. Elements live in `Sarvis/UI/Elements/{Input,Display}/<ElementName>/`. Adding a new element = drop a folder, register it. List the planned element types (TextInput, CalendarPicker, TimePicker, DurationPicker, TypeChip, ImportancePicker, ToggleRow, LocationPicker, AudioRecorder, AttachmentPicker, TodoList, SummaryCard, WeatherCard, NewsList, InsightCard, NudgeBanner, MapHotspots, ScreenTimeChart, EmailList, MoodIndicator, JSONViewer, ActionButton).
  - **File / folder structure** (the tree from the dispatcher's earlier proposal — `Sarvis/`, `prompts/`, `data/` runtime dir, `SarvisWidget/`).
  - **Storage layout** (`/data/raw/`, `/processed/`, `/email/`, `/location/`, `/screen_time/`, `/cache/` — note these resolve to the iOS Documents directory at runtime, not the repo).
  - **Tech stack** (Swift + SwiftUI · CoreLocation · BackgroundTasks · UNUserNotificationCenter · WidgetKit · App Intents · FamilyControls/DeviceActivity · Anthropic Claude API · Keychain).
  - **MVP phases** (preserve user's Phase 1–4 + email/screen-time additions).
  - **Setup / build** (xcodegen + Xcode 17, the existing `setup.sh` flow).
  - **Reality checks** (iOS background limits, battery, free-API quotas, screen-time API friction — keep this honest section).
  - **Roadmap** (short bulleted list of upcoming workers / unfinished pieces — e.g. dynamic UI composer build, widget completion, email integration, screen time integration, location intel).
- [x] **Use real markdown features:** `##` headings, fenced code blocks with language tags (`json`, `swift`, `bash`), tables only where they earn their space, no fluff. No emojis except where the user already used them in spirit (the original has 🧠🔔📊 etc. — light use is fine but don't carpet-bomb).
- [x] **Don't invent features** the user hasn't mentioned. If something's not in the source draft or in the dispatcher's plan, leave it out.
- [x] **Don't touch any other file.** This worker owns only `Readme.md`.
- [x] Write a one-paragraph summary to `.dispatch/tasks/rewrite-readme/output.md` listing: sections kept verbatim, sections restructured, anything intentionally cut.

**Constraints:**
- The rewrite must stand alone — a new contributor opening this repo should understand what Sarvis is, what's built, and what's planned, in 2 minutes of reading.
- Preserve the user's voice — direct, opinionated, "reality check" honesty. Don't sanitize it into corporate prose.
- The app **does not exist as Sarvis yet at this moment** — the rename worker is running in parallel. Write the README as if the rename is done (it will be by the time anyone reads it).
