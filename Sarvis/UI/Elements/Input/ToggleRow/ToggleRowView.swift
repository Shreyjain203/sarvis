import SwiftUI

/// A labeled toggle with an SF Symbol icon.
/// Writes a `Bool` (`AnyCodableValue.bool`) to the state bag.
/// Registers as `"Input/ToggleRow"`.
struct ToggleRowView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    private var cfg: ToggleRowConfig { ToggleRowConfig(spec: spec) }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: {
                guard let key = spec.bindingKey else { return false }
                return state.values[key]?.boolValue ?? false
            },
            set: { newVal in
                guard let key = spec.bindingKey else { return }
                state.values[key] = .bool(newVal)
            }
        )
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: cfg.symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.Palette.muted)
                .frame(width: 22)
            Text(cfg.label)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Palette.inkSoft)
            Spacer()
            Toggle("", isOn: toggleBinding)
                .labelsHidden()
                .tint(Theme.Palette.ink)
        }
        .themedCard(padding: Theme.Spacing.sm + 4, cornerRadius: Theme.Radius.card)
    }
}
