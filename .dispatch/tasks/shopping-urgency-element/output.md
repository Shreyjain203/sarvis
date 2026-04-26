# Shopping urgency element — implementation summary

## Binding shape

`ShoppingItemView` uses a single `bindingKey` that maps to an `.object` in `ScreenState.values`:

```json
{
  "text":    "<item name string>",
  "urgency": "<ShoppingUrgency rawValue>"
}
```

Both sub-keys are always written together so consumers never see a partial object.  
Default urgency (applied on first interaction): `nextVisit`.

## Urgency enum

```swift
enum ShoppingUrgency: String, Codable, CaseIterable, Identifiable {
    case today      // "Today"     / bolt.fill   — special trip today
    case nextVisit  // "Next visit"/ bag         — grab while already out
    case thisWeek   // "This week" / calendar    — within the week
    case someday    // "Someday"   / infinity    — no rush, future
}
```

### Visual treatment

Chips follow the same idiom as `TypeChipView` / `ImportancePickerView`:

- Unselected: `.ultraThinMaterial` fill + `Theme.Palette.hairline` stroke, `Theme.Palette.inkSoft` label.
- Selected: `Theme.Palette.ink` fill with a `matchedGeometryEffect` (namespace: `shoppingUrgencyNS`, id: `"shoppingUrgencyIndicator_<spec.id>"`), white label.
- Wrapped in a horizontal `ScrollView` so all 4 chips fit without crowding on narrow screens.
- Animated via `.spring(response: 0.35, dampingFraction: 0.85)`.
- Haptic feedback via `Haptics.soft()` on selection.

The outer container uses `.themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)` matching the rest of the element library.

## How a ScreenDefinition specifies this element

```json
{
  "id": "shopping-item-1",
  "type": "Input/ShoppingItem",
  "bindingKey": "shoppingItem",
  "config": {}
}
```

`CaptureScreenDynamic` (or a future shopping-only screen) would include this spec in its `ScreenDefinition.elements` array. After the user fills in the item and picks an urgency, `ScreenState.values["shoppingItem"]` will contain:

```json
{ "text": "Oat milk", "urgency": "thisWeek" }
```

A downstream `InputProcessor` / classifier can read `values["shoppingItem"]` directly and destructure the object into text + urgency without any extra parsing.
