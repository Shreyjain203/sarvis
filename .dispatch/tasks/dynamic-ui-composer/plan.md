# Dynamic UI Composer + first elements

Build the data-driven UI engine: screens are `ScreenDefinition`s composed of `ElementSpec`s; elements are plug-ins registered in a central `ElementRegistry`. Add the registry, the composer, the data types, and the first batch of elements. Retrofit the existing capture screen to use it (so we prove the engine works end-to-end). Other screens stay as-is for now — the composer is opt-in.

- [x] **Add data types in `Sarvis/Models/`:**
  - `ElementSpec.swift` — struct describing one element on a screen:
    ```swift
    struct ElementSpec: Identifiable, Codable {
        let id: String           // unique within the screen
        let type: String         // matches a key in ElementRegistry
        let config: [String: AnyCodableValue]   // element-specific knobs
        let bindingKey: String?  // path into the screen's state bag
    }
    ```
  - `ScreenDefinition.swift` — `struct ScreenDefinition: Codable { let id: String; let title: String; let elements: [ElementSpec] }`.
  - `AnyCodableValue.swift` — small JSON-value enum (`.string`, `.int`, `.double`, `.bool`, `.array`, `.object`, `.null`) with `Codable` conformance, so element configs can be loaded from JSON without bespoke types per element. Keep it tiny.
  <!-- All three files created at Sarvis/Models/{AnyCodableValue,ElementSpec,ScreenDefinition}.swift -->
- [x] **Add `Sarvis/UI/Composer/`:**
  - `ElementRegistry.swift` — factory map + `registerBuiltIns()` wiring all 7 built-ins.
  - `ScreenState.swift` — `@MainActor ObservableObject` with `values` bag + `binding(for:default:)` helper.
  - `DynamicScreen.swift` — renders title + iterates elements via registry; exposes `onAction` via `@Environment(\.dynamicScreenAction)`.
  - `UnknownElementView.swift` — hairline-bordered monospaced fallback.
  <!-- All four files created at Sarvis/UI/Composer/ -->
- [x] **Add first batch of elements** under `Sarvis/UI/Elements/`. Each in its own folder with `<Name>View.swift` + `<Name>Config.swift`. Each registers itself by calling `ElementRegistry.shared.register("ElementType", factory:)` in `registerBuiltIns()` (do NOT use Swift's @main + global side-effects — keep registration explicit and testable).
  - **Input/TextInput** — multi-line `TextEditor`, placeholder, `lineLimit` from config, hero serif typography matching current `InputView`. Config: `placeholder: String`, `multiline: Bool`, `minHeight: Double`.
  - **Input/CalendarPicker** — inline `DatePicker` styled `.graphical`. Config: `mode: "date" | "dateAndTime" | "time"`, `optional: Bool`. Writes to binding as ISO-8601 string (or null).
  - **Input/TypeChip** — horizontal scroll row of `InputType` chips, matching the existing chip idiom in InputView. Config: empty (uses `InputType.allCases`). Writes the selected type's `rawValue`.
  - **Input/ImportancePicker** — three chip toggles for `Importance.low/.medium/.high`. Same matchedGeometryEffect treatment as the existing one. Config: empty.
  - **Input/ToggleRow** — labeled toggle (icon + text + Toggle). Config: `label: String`, `symbol: String` (SF Symbol).
  - **Display/SummaryCard** — themed card showing a title + body text from the binding. Config: `title: String?`. If binding is empty, renders a muted placeholder.
  <!-- All elements created in their own folders under Sarvis/UI/Elements/Input/ and Display/ -->
- [x] **Retrofit the capture screen** at `Sarvis/Screens/InputView.swift`:
  - FALLBACK PATH TAKEN: `InputView.swift` is left untouched. New dynamic version is `Sarvis/Screens/CaptureScreenDynamic.swift`. To switch, replace `InputView()` with `CaptureScreenDynamic()` in `RootView.swift`. Documented in output.md.
  - `captureScreen` ScreenDefinition defined in code in `CaptureScreenDynamic.swift` with all 7 elements including `Display/ActionButton`.
  - `"capture.save"` action reads state values → schedules notification → `TodoStore.shared.capture(...)` → `ToastCenter.shared.show("Saved")` → `state.reset()`.
  - `"capture.aiAssist"` action wired to `LLMService.ask(...)` with llmDraft overlay banner.
- [x] **Wire registration in `Sarvis/App/SarvisApp.swift`:** added `ElementRegistry.shared.registerBuiltIns()` to `init()`. No other existing setup touched.
- [x] **Run `swift -frontend -parse`** on every new + modified file. All 14 new files + SarvisApp.swift parsed cleanly (no output = no errors).
- [x] **Run `xcodegen generate`** so the new files are picked up by the Xcode project. Exit code 0. ✓
- [x] Write a summary to `.dispatch/tasks/dynamic-ui-composer/output.md` covering all required sections.

**Constraints:**
- iOS 17+. SwiftUI only. No third-party deps.
- Don't break the existing build. If retrofit risks regressions, ship the dynamic version as a parallel screen and document it.
- Don't touch any file under `SarvisWidget/` — a parallel worker (`finish-widget`) is editing those.
- Don't touch `Sarvis/Screens/QuickCaptureSheet.swift` if it appears — that's also the widget worker's territory.
- Element folders strictly: `Sarvis/UI/Elements/Input/<Name>/<Name>View.swift` (+ optional `<Name>Config.swift`). Don't put two elements in one file.
- Use `Theme.Spacing`, `Theme.Palette`, `Theme.Radius` for all visual decisions. No magic numbers in element views.
- Match existing visual idiom — the elements should feel like they came from the same hand as `InputView`.
