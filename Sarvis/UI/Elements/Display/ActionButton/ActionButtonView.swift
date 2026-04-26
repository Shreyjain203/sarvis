import SwiftUI

/// A full-width themed primary button that fires a named action through the
/// `DynamicScreen` action dispatch mechanism.
/// Registers as `"Display/ActionButton"`.
struct ActionButtonView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    @Environment(\.dynamicScreenAction) private var onAction

    private var cfg: ActionButtonConfig { ActionButtonConfig(spec: spec) }

    var body: some View {
        Button {
            Haptics.light()
            onAction(cfg.action)
        } label: {
            Text(cfg.title)
                .font(Theme.Typography.bodyEmphasis())
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(Theme.Palette.ink)
                }
        }
        .buttonStyle(.plain)
    }
}
