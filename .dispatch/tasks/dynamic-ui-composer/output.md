# Dynamic UI Composer — Implementation Summary

## Data model

### `AnyCodableValue` (`Sarvis/Models/AnyCodableValue.swift`)
A small JSON-value enum with cases `.string`, `.int`, `.double`, `.bool`, `.array`, `.object`, `.null`. Fully `Codable` + `Equatable`. Provides `.stringValue`, `.intValue`, `.doubleValue`, `.boolValue` convenience accessors. Enables typed element configs without per-element bespoke Codable.

### `ElementSpec` (`Sarvis/Models/ElementSpec.swift`)
```swift
struct ElementSpec: Identifiable, Codable {
    let id: String                        // unique within screen
    let type: String                      // key in ElementRegistry
    let config: [String: AnyCodableValue] // element-specific knobs
    let bindingKey: String?               // path into ScreenState.values
}
```

### `ScreenDefinition` (`Sarvis/Models/ScreenDefinition.swift`)
```swift
struct ScreenDefinition: Codable {
    let id: String
    let title: String
    let elements: [ElementSpec]
}
```

### `ScreenState` (`Sarvis/UI/Composer/ScreenState.swift`)
`@MainActor final class ScreenState: ObservableObject`. Holds `@Published var values: [String: AnyCodableValue]`. Elements read/write via `bindingKey`. Provides `binding(for:default:)` for two-way SwiftUI bindings, plus `string(for:)`, `bool(for:)`, and `reset()` helpers.

---

## `ElementRegistry` API — registering a new element in 4 lines

```swift
ElementRegistry.shared.register("MyNS/MyElement") { spec, state in
    AnyView(MyElementView(spec: spec, state: state))
}
```

Add that call inside `registerBuiltIns()` in `ElementRegistry.swift`. The element is immediately available to any `ScreenDefinition` that references its type string.

---

## Built-in element catalog

| Type string | File | Binding type | Notes |
|---|---|---|---|
| `Input/TextInput` | `…/TextInput/TextInputView.swift` | `AnyCodableValue.string` | Hero serif TextEditor; config: `placeholder`, `multiline`, `minHeight` |
| `Input/TypeChip` | `…/TypeChip/TypeChipView.swift` | `AnyCodableValue.string` (InputType.rawValue) | Horizontal scroll row; no config |
| `Input/ImportancePicker` | `…/ImportancePicker/ImportancePickerView.swift` | `AnyCodableValue.int` (Importance.rawValue) | Three chips with matchedGeometryEffect; no config |
| `Input/ToggleRow` | `…/ToggleRow/ToggleRowView.swift` | `AnyCodableValue.bool` | config: `label: String`, `symbol: String` (SF Symbol) |
| `Input/CalendarPicker` | `…/CalendarPicker/CalendarPickerView.swift` | `AnyCodableValue.string` (ISO-8601) or `.null` | Inline .graphical DatePicker; config: `mode` (`"date"/"dateAndTime"/"time"`), `optional: Bool` |
| `Display/SummaryCard` | `…/SummaryCard/SummaryCardView.swift` | `AnyCodableValue.string` | Reads body text from binding; config: `title: String?` |
| `Display/ActionButton` | `…/ActionButton/ActionButtonView.swift` | — (no binding) | Full-width primary button; config: `title: String`, `action: String` |

---

## Retrofitted capture screen

### File: `Sarvis/Screens/CaptureScreenDynamic.swift`

**Approach taken: parallel screen (fallback path)**
The original `InputView.swift` is left fully intact. The dynamic version lives in `CaptureScreenDynamic.swift`. To switch production to the new screen, replace `InputView()` with `CaptureScreenDynamic()` in `RootView.swift`.

**How it loads:**
A `captureScreen: ScreenDefinition` is defined in code at the top of the file. It lists 7 element specs: TextInput, TypeChip, ImportancePicker, ToggleRow (sensitive), CalendarPicker (optional dueAt), plus two ActionButtons.

**Action dispatch:**
`DynamicScreen.onAction` receives `(actionID: String, state: ScreenState)`. The two wired actions are:
- `"capture.save"` — reads `text`, `inputType`, `importance`, `isSensitive`, `dueAt` from `state.values`; runs notification scheduling; calls `TodoStore.shared.capture(...)`; calls `ToastCenter.shared.show("Saved")`; calls `state.reset()`.
- `"capture.aiAssist"` — passes the current text to `LLMService.ask(...)`, stores the result in a local `@State var llmDraft`, and shows an overlay banner.

**AI assist note:** The LLM draft banner is an overlay on `CaptureScreenDynamic` itself — it can't inject text back into `ScreenState` without a shared observable. Full "Use this version" reinject is a known gap (see below).

---

## Registration

`ElementRegistry.shared.registerBuiltIns()` is called from `SarvisApp.init()` (one-liner addition — other setup is untouched).

---

## JSON loading — NOT YET IMPLEMENTED

`ScreenDefinition` is fully `Codable`, so loading from JSON requires only:
```swift
let data = try Data(contentsOf: bundle.url(forResource: "capture", withExtension: "json")!)
let def = try JSONDecoder().decode(ScreenDefinition.self, from: data)
```
Next step: add `Sarvis/Resources/Screens/*.json` files and a `ScreenLoader` that reads them from the bundle (or a remote URL). The next worker should create the loader and add the JSON files to `project.yml` under `resources`.

---

## Known gaps / TODOs

1. **LLM draft re-inject into state** — `CaptureScreenDynamic` stores `llmDraft` in local `@State`. Injecting it back into `ScreenState.values["text"]` requires either exposing `ScreenState` out of `DynamicScreen` (e.g. via a `@Binding<ScreenState>` parameter) or a shared `@StateObject` above both layers. Marked for next iteration.
2. **JSON loading** — see above. `ScreenDefinition` is ready; just needs the loader + JSON files.
3. **Notification-enable toggle** — the original `InputView` had a `NotificationPill` toggle (`enableNotification`). In the dynamic screen the CalendarPicker is always rendered (optional: true). A cleaner UX would gate the CalendarPicker on a `ToggleRow("Enable reminder")` and hide it when off; conditional rendering based on another element's binding is not yet in the composer.
4. **Conditional element visibility** — no `visible: String?` (expression referencing other binding keys) in `ElementSpec` yet. Straightforward to add.
5. **Settings sheet** — the gearshape toolbar button in `CaptureScreenDynamic` doesn't open `SettingsView` yet (intentionally minimal; original `InputView` has it).
6. **`ScreenDefinition` from JSON** — the `captureScreen` constant in `CaptureScreenDynamic.swift` is defined in code. It should migrate to `Sarvis/Resources/Screens/capture.json` once the loader exists.
