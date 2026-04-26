import SwiftUI

/// Combined text + urgency-chip input for shopping-list captures.
///
/// Binding shape (written to `ScreenState.values[bindingKey]`):
/// ```
/// .object([
///     "text":    .string("…"),
///     "urgency": .string(ShoppingUrgency.rawValue)
/// ])
/// ```
/// Default urgency: `.nextVisit`.
/// Registers as `"Input/ShoppingItem"`.
struct ShoppingItemView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    @Namespace private var shoppingUrgencyNS
    @FocusState private var textFieldFocused: Bool

    // MARK: - Derived state helpers

    private var currentObject: [String: AnyCodableValue] {
        guard let key = spec.bindingKey,
              case .object(let obj) = state.values[key] else { return [:] }
        return obj
    }

    private var itemText: String {
        currentObject["text"]?.stringValue ?? ""
    }

    private var selectedUrgency: ShoppingUrgency {
        guard let raw = currentObject["urgency"]?.stringValue,
              let u = ShoppingUrgency(rawValue: raw) else { return .nextVisit }
        return u
    }

    // MARK: - Mutations

    private func updateText(_ newText: String) {
        guard let key = spec.bindingKey else { return }
        var obj = currentObject
        obj["text"] = .string(newText)
        if obj["urgency"] == nil {
            obj["urgency"] = .string(ShoppingUrgency.nextVisit.rawValue)
        }
        state.values[key] = .object(obj)
    }

    private func selectUrgency(_ urgency: ShoppingUrgency) {
        guard let key = spec.bindingKey else { return }
        Haptics.soft()
        var obj = currentObject
        obj["urgency"] = .string(urgency.rawValue)
        if obj["text"] == nil {
            obj["text"] = .string("")
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            state.values[key] = .object(obj)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            textRow
            urgencyRow
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var textRow: some View {
        ZStack(alignment: .leading) {
            if itemText.isEmpty {
                Text("Item")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Palette.muted.opacity(0.7))
                    .allowsHitTesting(false)
            }
            TextField("", text: Binding(
                get: { itemText },
                set: { updateText($0) }
            ))
            .font(Theme.Typography.body())
            .tint(Theme.Palette.ink)
            .focused($textFieldFocused)
        }
    }

    @ViewBuilder
    private var urgencyRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Urgency")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(ShoppingUrgency.allCases) { urgency in
                        chipButton(for: urgency)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipButton(for urgency: ShoppingUrgency) -> some View {
        let isSelected = selectedUrgency == urgency
        Button {
            selectUrgency(urgency)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: urgency.symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(urgency.label)
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : Theme.Palette.inkSoft)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(Theme.Palette.ink)
                        .matchedGeometryEffect(id: "shoppingUrgencyIndicator_\(spec.id)", in: shoppingUrgencyNS)
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
