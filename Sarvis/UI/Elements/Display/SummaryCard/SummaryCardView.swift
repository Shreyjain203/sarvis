import SwiftUI

/// A themed card showing an optional title and body text from the binding.
/// When the binding is empty, renders a muted placeholder.
/// Registers as `"Display/SummaryCard"`.
struct SummaryCardView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    private var cfg: SummaryCardConfig { SummaryCardConfig(spec: spec) }

    private var bodyText: String? {
        guard let key = spec.bindingKey else { return nil }
        return state.values[key]?.stringValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let title = cfg.title {
                Text(title.uppercased())
                    .font(Theme.Typography.meta())
                    .tracking(1)
                    .foregroundStyle(Theme.Palette.muted)
            }
            if let text = bodyText, !text.isEmpty {
                Text(text)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(Theme.Palette.inkSoft)
            } else {
                Text("Nothing here yet.")
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(Theme.Palette.muted.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }
}
