# Shopping urgency element

New dynamic-UI input element: a single row combining a text field + 3 urgency chips (Now / Soon / Later). Used for shopping captures.

- [x] **Add `Sarvis/UI/Elements/Input/ShoppingItem/`** with two files: — created ShoppingItemConfig.swift + ShoppingItemView.swift
  - `ShoppingItemConfig.swift` — `enum ShoppingUrgency: String, Codable, CaseIterable { case today, nextVisit, thisWeek, someday }` with `label` and `symbol` computed properties:
    - `.today` → "Today" / `bolt.fill` (special trip today)
    - `.nextVisit` → "Next visit" / `bag` (grab next time you're already out)
    - `.thisWeek` → "This week" / `calendar` (within the week)
    - `.someday` → "Someday" / `infinity` (no rush, future)
  - `ShoppingItemView.swift` — SwiftUI `View` taking `ElementSpec` + `ScreenState`. Layout: a vertical stack of `[TextField placeholder: "Item", horizontal scroll of 4 urgency chips]`, themed via `Theme.Spacing`/`Palette`/`Radius`. Chips reuse the same idiom as `TypeChipView` and `ImportancePickerView` — `matchedGeometryEffect` over a separate namespace `shoppingUrgencyNS`. Use a horizontal `ScrollView` so 4 chips don't crowd. Selection writes to binding as a `ScreenState` object: `[ "text": .string(...), "urgency": .string(rawValue) ]` (using `AnyCodableValue`). Default urgency: `.nextVisit`.
- [x] **Register in `Sarvis/UI/Composer/ElementRegistry.swift`** inside `registerBuiltIns()`. Add a single line:
  ```swift
  register("ShoppingItem") { spec, state in AnyView(ShoppingItemView(spec: spec, state: state)) }
  ```
  Place it adjacent to the existing input-element registrations to keep the file readable. Use the Edit tool with the exact existing closing brace as anchor — do NOT replace the whole method.
- [x] **Verification:** `swift -frontend -parse` on the two new files + `ElementRegistry.swift`. `xcodegen generate` exit 0. — both passed clean.
- [x] Write a summary to `.dispatch/tasks/shopping-urgency-element/output.md`: the element's binding shape (object with `text` + `urgency`), the urgency enum + its visual treatment, and how `CaptureScreenDynamic` (or a future shopping-only screen) would specify it in its `ScreenDefinition`.

**Constraints:**
- iOS 17+. SwiftUI only.
- Match the existing element visual idiom (chip style, materials, spacing).
- Don't touch other elements, other screens, or services.
- Stay under `Sarvis/UI/Elements/Input/ShoppingItem/` for new files; only edit `ElementRegistry.swift` outside that folder.
- A parallel worker (`classifier-pipeline`) is editing `Sarvis/Screens/CaptureScreenDynamic.swift` and `Sarvis/Services/`. Don't touch those.
- A parallel worker (`morning-and-quotes-jobs`) is editing `Sarvis/App/SarvisApp.swift` and `Sarvis/Services/Notifications/`. Don't touch those.
