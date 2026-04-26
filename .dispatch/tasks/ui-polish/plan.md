# UI polish: minimalistic, classy, rich

Make the existing SwiftUI screens (InputView, TodayView, SettingsView, RootView) feel like a hand-crafted indie app — restrained, typographic, with subtle depth. **Functionality must not regress.** Don't rename types, don't change `TodoStore` / `NotificationService` / `LLMService` APIs.

- [x] Read all five existing view files in `ReminderApp/App/` and `ReminderApp/Screens/` to understand current structure
- [x] Add a new file `ReminderApp/UI/Theme.swift` defining: a serif+rounded font palette (e.g. `Font.system(.title, design: .serif)`), spacing constants, corner radii, and a soft layered background gradient. No third-party deps. (Includes Haptics + CardStyle modifier.)
- [x] Replace the default `TabView` in `RootView.swift` with a custom bottom bar: two pill buttons ("Capture" / "Today") in a glass/blur capsule using `.ultraThinMaterial`, with a subtle indicator behind the active tab. Keep the same two screens. (matchedGeometryEffect indicator + soft haptic on switch.)
- [x] Redesign `InputView.swift`:
  - Hero text editor on a soft layered background (no `Form` chrome). Use a large `TextEditor` styled like paper, with a placeholder.
  - Importance picker → segmented row of four small chips (low/medium/high/critical) using the symbols already in `Importance.symbol`. Selected chip animates with `.matchedGeometryEffect`.
  - Sensitive toggle → a small lock pill that flips state with a soft haptic. Use `UIImpactFeedbackGenerator(style: .soft)`.
  - Reminder time → inline `DatePicker(.compact)` styled into the layout, not in a Form section.
  - "Clean up with Claude" → a discreet sparkles button in a rounded rect with a subtle shimmer when loading.
  - Primary "Save" button → full-width, rounded, monochrome, with confidence (no SF Symbol clutter).
- [x] Redesign `TodayView.swift`:
  - Header: large serif "Today" + today's date (e.g. "Saturday, April 25") in a muted secondary tone.
  - Sensitive section: subtle red-tinted card at the top with a lock icon, NOT alarming — refined.
  - Per-importance groups become section headers with a tiny colored dot (low: gray, medium: blue, high: orange, critical: red).
  - Each `TodoRow`: floating card with `.ultraThinMaterial` background, generous padding, a circular check button on the left, two-line text (todo + meta row), trailing chevron, soft shadow. Strikethrough done state should fade text to ~40% opacity.
  - Empty state: centered serif "Nothing for today" with a small caption beneath, no SF Symbol.
- [x] Redesign `SettingsView.swift` similarly: stop using raw `Form`. Group fields into floating cards with the same Theme constants. Keep field bindings unchanged.
- [x] Update `project.yml` if a new `ReminderApp/UI/` folder needs to be picked up (XcodeGen recurses sources, so verify but likely no change needed). Re-run `xcodegen generate` to regenerate the project. (No project.yml change needed — XcodeGen recursed `ReminderApp/UI/Theme.swift` automatically.)
- [x] Run `swift -frontend -parse` on every changed/new Swift file to confirm syntax. Then attempt a build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ReminderApp.xcodeproj -scheme ReminderApp -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build` — if it fails on the Xcode license, note that and stop (user must accept it once). (All five files parsed cleanly. xcodebuild blocked on unaccepted Xcode license — user must run `sudo xcodebuild -license` once. See output.md.)
- [x] Write a summary of changes to `.dispatch/tasks/ui-polish/output.md` listing every file touched, the design language used (fonts, spacing scale, palette), and the two or three places most worth iterating on.

**Constraints:**
- iOS 17+ APIs are fine (project is iOS 17 deployment target).
- No new dependencies. SwiftUI + SF Symbols only.
- Don't change file paths of existing types or break `@EnvironmentObject` / `@StateObject` wiring.
- Light AND dark mode must look intentional — test mentally for both.
- Keep accessibility: dynamic type should still scale, contrast on text ≥ secondary level.
