import SwiftUI

/// Renders a `ScreenDefinition` by iterating its `ElementSpec`s and asking
/// `ElementRegistry` for the corresponding view.
///
/// Action dispatch: embed an `onAction` closure in the environment. Elements
/// (e.g. `ActionButtonView`) read it via `@Environment(\.dynamicScreenAction)`
/// and call it with the action string from their config.
struct DynamicScreen: View {
    let definition: ScreenDefinition

    /// Called when an element fires an action (e.g. a button tap).
    var onAction: ((String, ScreenState) -> Void)?

    @StateObject private var state = ScreenState()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Screen title header
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.title)
                        .font(Theme.Typography.title())
                        .foregroundStyle(Theme.Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Elements
                ForEach(definition.elements) { spec in
                    ElementRegistry.shared.make(spec, state: state)
                }

                // Bottom breathing room for tab bar
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
        }
        .dismissKeyboardToolbar()
        .environment(\.dynamicScreenAction, { actionID in
            onAction?(actionID, state)
        })
    }
}

// MARK: - Environment key for action dispatch

private struct DynamicScreenActionKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var dynamicScreenAction: (String) -> Void {
        get { self[DynamicScreenActionKey.self] }
        set { self[DynamicScreenActionKey.self] = newValue }
    }
}
