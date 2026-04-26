# Toast + Keyboard "Done" — API Reference

## ToastCenter.shared.show(_:duration:)

```swift
ToastCenter.shared.show("Saved")               // 1.6 s default
ToastCenter.shared.show("API key cleared")
ToastCenter.shared.show("Copied", duration: 2.0)
```

`ToastCenter` is a `@MainActor` `ObservableObject` singleton. Each call to `show(_:)` cancels the previous auto-clear `Task`, so rapid successive calls replace the current toast rather than stacking.

## .toastHost()

Apply once at the outermost `ZStack` in `RootView`. It overlays a capsule banner 88 pt above the bottom edge (clears the floating tab bar).

```swift
ZStack(alignment: .bottom) { … }
    .toastHost()
```

## .dismissKeyboardToolbar()

Apply to any view that contains focused text fields (e.g. `NavigationStack`, `Form`, `ScrollView`). Adds a "Done" button to the keyboard accessory bar that resigns the first responder.

```swift
NavigationStack { … }
    .dismissKeyboardToolbar()
```

## Visual treatment

| Property | Value |
|---|---|
| Background | `.ultraThinMaterial` capsule |
| Stroke | `Theme.Palette.hairline` (0.5 pt) |
| Text | `Theme.Typography.bodyEmphasis()` / `Theme.Palette.ink` |
| Padding | `Theme.Spacing.md` × `Theme.Spacing.sm` |
| Position | 88 pt above safe-area bottom (above tab bar) |
| Insertion | `.opacity` + `.move(edge: .bottom)` |
| Removal | `.opacity` |
| Spring | `response: 0.38, dampingFraction: 0.82` |
| Default duration | 1.6 s |

## Potential iteration areas

1. **Toast severity variants** — add a `ToastKind` enum (`.info`, `.success`, `.error`) and tint the capsule stroke/icon accordingly (green for success, red for error, default for info).
2. **Swipe-to-dismiss** — attach a `.gesture(DragGesture(…))` to `ToastBanner` so users can flick the toast away early; cancel the auto-clear task on swipe.
3. **Queue instead of replace** — buffer successive `show` calls so each message is visible for its full duration before the next one animates in, rather than immediately replacing the current message.
