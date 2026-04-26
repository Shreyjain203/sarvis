# Toast + keyboard "Done" accessory

Add a global toast and a keyboard-dismiss accessory matching the app's design language. Implement the API surface and apply it to RootView and SettingsView. **Do NOT touch `InputView.swift`** — a parallel worker is rewriting it and will apply both modifiers itself.

- [x] Add `ReminderApp/UI/Toast.swift` containing:
  - `final class ToastCenter: ObservableObject` singleton (`ToastCenter.shared`) with `@Published var message: String?` and `func show(_ message: String, duration: TimeInterval = 1.6)` that auto-clears after the duration. Internally uses a `Task` and `await Task.sleep` so successive `show` calls cancel the prior auto-clear.
  - `View.toastHost()` modifier: overlays a small `.ultraThinMaterial` capsule near the bottom (above the floating tab bar — z-order matters), animated in/out with `.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity)`. Uses `Theme.Palette` (ink text, hairline stroke), `Theme.Spacing`, `Theme.Radius.pill`. Must not block touches when no toast is showing.
  - `View.dismissKeyboardToolbar()` modifier implemented as specified.
  — Created at `ReminderApp/UI/Toast.swift`. Swift parse: no errors.
- [x] Update `ReminderApp/App/RootView.swift` — applied `.toastHost()` on the outer `ZStack` so toasts appear above the tab bar. Swift parse: no errors.
- [x] Update `ReminderApp/Screens/SettingsView.swift`:
  - Applied `.dismissKeyboardToolbar()` to the `NavigationStack`.
  - Replaced `savedFlash` text with `ToastCenter.shared.show("Saved")` on successful save.
  - On Clear API key: `ToastCenter.shared.show("API key cleared")`.
  - Removed `savedFlash` state and the conditional `Text("Saved.")` view.
  — Swift parse: no errors.
- [x] **Do NOT modify `InputView.swift`.** — not touched.
- [x] Run `swift -frontend -parse` on `Toast.swift`, `RootView.swift`, `SettingsView.swift`. — All three passed with zero diagnostics.
- [x] Write a summary to `.dispatch/tasks/toast-and-keyboard/output.md` documenting the API, visual treatment, and iteration ideas. — Written.

**API contract (consumed by other workers):**
- `ToastCenter.shared.show("Saved")` — show a 1.6s toast.
- `.dismissKeyboardToolbar()` — view modifier added to any view containing focused text input.

**Constraints:**
- iOS 17+.
- No third-party deps.
- Reuse existing `Theme` and `Haptics` from `ReminderApp/UI/Theme.swift`.
- The "Done" button must feel like part of the keyboard accessory bar — typographic, not a chunky filled button.
