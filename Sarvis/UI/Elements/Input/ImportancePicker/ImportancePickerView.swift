import SwiftUI

/// Three chip toggles for `Importance` levels with `matchedGeometryEffect`.
/// Writes the selected importance's `rawValue` (Int) to the state bag.
/// Registers as `"Input/ImportancePicker"`.
struct ImportancePickerView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    @Namespace private var ns

    private var selected: Importance {
        guard let key = spec.bindingKey,
              let i = state.values[key]?.intValue,
              let imp = Importance(rawValue: i) else { return .medium }
        return imp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Importance")
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Importance.allCases) { imp in
                    chipButton(for: imp)
                }
            }
        }
    }

    @ViewBuilder
    private func chipButton(for imp: Importance) -> some View {
        let isSelected = selected == imp
        Button {
            Haptics.soft()
            guard let key = spec.bindingKey else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                state.values[key] = .int(imp.rawValue)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: imp.symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(imp.label)
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : Theme.Palette.inkSoft)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(Theme.Palette.ink)
                        .matchedGeometryEffect(id: "importanceChipIndicator_\(spec.id)", in: ns)
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.Typography.meta())
            .tracking(1)
            .foregroundStyle(Theme.Palette.muted)
    }
}
