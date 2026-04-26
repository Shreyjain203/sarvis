import SwiftUI

// MARK: - ToastCenter

/// Global toast coordinator. Inject into the environment via `.toastHost()`.
@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published var message: String?

    private var clearTask: Task<Void, Never>?

    private init() {}

    /// Show a brief banner. Successive calls cancel the previous auto-clear.
    func show(_ message: String, duration: TimeInterval = 1.6) {
        clearTask?.cancel()
        self.message = message
        clearTask = Task { [weak self] in
            let nanoseconds = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self?.message = nil
            }
        }
    }
}

// MARK: - ToastHostModifier

private struct ToastHostModifier: ViewModifier {
    @StateObject private var center = ToastCenter.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let msg = center.message {
                ToastBanner(message: msg)
                    // Sit above the floating tab bar (approx 72 pt) plus a little breathing room
                    .padding(.bottom, 88)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        )
                    )
                    .allowsHitTesting(false)
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: center.message)
    }
}

// MARK: - ToastBanner

private struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(Theme.Typography.bodyEmphasis())
            .foregroundStyle(Theme.Palette.ink)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                    )
            }
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - DismissKeyboardToolbarModifier

private struct DismissKeyboardToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        Haptics.light()
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                    .font(Theme.Typography.bodyEmphasis())
                    .foregroundStyle(Theme.Palette.ink)
                }
            }
    }
}

// MARK: - View extensions

extension View {
    /// Overlay a toast host above the floating tab bar. Apply once at the root of the view hierarchy.
    func toastHost() -> some View {
        modifier(ToastHostModifier())
    }

    /// Add a "Done" button to the keyboard accessory bar that dismisses the first responder.
    func dismissKeyboardToolbar() -> some View {
        modifier(DismissKeyboardToolbarModifier())
    }
}
