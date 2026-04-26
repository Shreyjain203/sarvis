import SwiftUI

/// A horizontal scroll row of `InputType` chips, matching the existing idiom
/// in `InputView`. Writes the selected type's `rawValue` to the state bag.
/// Registers as `"Input/TypeChip"`.
struct TypeChipView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    @Namespace private var ns

    private var selectedType: InputType {
        guard let key = spec.bindingKey,
              let raw = state.values[key]?.stringValue,
              let t = InputType(rawValue: raw) else { return .task }
        return t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Type")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(InputType.allCases) { type in
                        chipButton(for: type)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipButton(for type: InputType) -> some View {
        let isSelected = selectedType == type
        Button {
            Haptics.soft()
            guard let key = spec.bindingKey else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                state.values[key] = .string(type.rawValue)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(type.label)
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : Theme.Palette.inkSoft)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(Theme.Palette.ink)
                        .matchedGeometryEffect(id: "typeChipIndicator_\(spec.id)", in: ns)
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
