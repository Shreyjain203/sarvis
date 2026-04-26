# UI Polish — Summary

A restrained, indie-feeling redesign of the Reminder app: serif headings, soft layered backgrounds, ultraThinMaterial cards, monochrome ink primary, subtle haptics. No service / store / model APIs were touched.

## Files touched

| File | Change |
| --- | --- |
| `ReminderApp/UI/Theme.swift` | **New.** Single source of truth for spacing, radii, typography, palette, layered background, card modifier (`.themedCard()`), and `Haptics` helper. |
| `ReminderApp/App/RootView.swift` | Replaced `TabView` with a custom floating capsule tab bar (`.ultraThinMaterial`, `matchedGeometryEffect` indicator, soft haptic on switch). |
| `ReminderApp/Screens/InputView.swift` | Full redesign — hero serif `TextEditor`, importance chips with shared geometry, lock & bell pills, inline compact `DatePicker`, sparkles button with shimmer, monochrome full-width Save. No `Form`. |
| `ReminderApp/Screens/TodayView.swift` | Full redesign — large serif "Today" + dated subtitle, sensitive section as soft red-tinted card, importance groups with colored dots, each `TodoRow` is a floating material card with circular check button, fading strikethrough, and chevron. Editorial empty state. |
| `ReminderApp/Screens/SettingsView.swift` | Stripped raw `Form`. Same Theme cards for API key + model + max tokens. Monochrome Save, hairline-bordered destructive Clear. |
| `project.yml` | No change — XcodeGen recursed `ReminderApp/UI/` automatically. |
| `ReminderApp.xcodeproj` | Regenerated via `xcodegen generate`; Theme.swift now compiled. |

## Design language

**Typography**
- Editorial **serif** for hero / section headings (`Font.system(.title, design: .serif)`), todo body text, and the `TextEditor` placeholder.
- **Rounded** for chrome (chips, buttons, meta) — `.system(.body, design: .rounded)`.
- **Monospaced** only for technical values (API key, model ID, token count).

**Spacing scale** (`Theme.Spacing`): `hair 2 · xs 6 · sm 10 · md 16 · lg 22 · xl 32 · xxl 48`. 8-pt rhythm with 4-pt micro-tweaks.

**Radii** (`Theme.Radius`): `chip 12 · card 20 · hero 28 · pill 999`.

**Palette** (semantic, dark-mode safe): `ink` = `Color.primary`, `muted` = `Color.secondary`, `paper` / `card` from `secondarySystemBackground` / `tertiarySystemBackground`, `hairline` = primary @ 8%. Importance dots: gray / blue / orange / red, each desaturated. Sensitive tint: red @ 10% with 70% accent — refined, not alarming.

**Layered background**: `Color(uiColor:.systemBackground)` + a soft top-to-bottom gradient + two faint radial washes (warm top-left, cool bottom-right) — invisible-but-felt depth in both modes.

**Cards**: `.ultraThinMaterial` over a continuous rounded rect, hairline stroke border, soft black-6% shadow at `y: 6 · radius: 14`.

**Motion & haptics**
- Tab switch, importance chip select, lock pill, save: `Haptics.soft()`.
- Toolbar gear / Done / Clear key: `Haptics.light()`.
- Successful save / settings save: `Haptics.success()`.
- Spring `(response 0.35–0.4, damping 0.85)` for state changes.
- Sparkles button shimmers via a moving white-60% gradient mask while `llm.isSending`.

## Build status

`swift -frontend -parse` passes cleanly on all five files (Theme, RootView, InputView, TodayView, SettingsView).

`xcodebuild` was blocked by an unaccepted Xcode license:

```
You have not agreed to the Xcode license agreements.
Please run 'sudo xcodebuild -license' from within a Terminal window…
```

**Action for user**: run `sudo xcodebuild -license` once, then re-run the same `xcodebuild` command from the plan. No source-level fixes are expected — every file parses, types and APIs (`TodoStore`, `LLMService`, `NotificationService`, `KeychainService`, `Importance`, `TodoItem`) are unchanged.

## Worth iterating on

1. **Hero editor placeholder** — current implementation overlays a serif "What's on your mind?" because `TextEditor` has no native placeholder. Solid, but consider an attributed `AttributedString` placeholder with a soft caret guide if you want the paper feel sharper.
2. **Tab bar layering** — the floating capsule sits on a transparent `LayeredBackground`. Looks good, but on long content the bar can occlude the last row; the 96-pt bottom spacer mitigates this. If you push toward a `safeAreaInset(edge: .bottom)` pattern instead, content insetting becomes automatic.
3. **Importance dot colors** — currently semantic (`Color.blue`, `.orange`, `.red`) with opacity. They work, but if the app gets a Color Asset palette (e.g. `inkBlue`, `emberOrange`) you could push the indie feel further by moving away from system hues.
