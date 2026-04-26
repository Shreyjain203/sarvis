import SwiftUI

/// A shopping item card — item text plus an urgency chip.
///
/// Shopping-urgency-metadata gap (MVP note):
/// `TodoItem` currently has no explicit urgency field. For this MVP, the urgency
/// is inferred from the item `text` if it contains a keyword like
/// "today", "next visit", "this week", or "someday". Otherwise it defaults to
/// `.nextVisit`. This is a best-effort heuristic.
///
/// TODO: Add a `metadata: [String: AnyCodableValue]` field to `TodoItem` so that
/// element-specific data (e.g. shopping urgency, product URL, quantity) can be
/// stored without polluting the core model. The `ShoppingItemView` input element
/// should write `metadata["urgency"]` at capture time, and this display element
/// should read it. This gap is tracked in `.dispatch/tasks/processed-viewer-screen/output.md`.
///
/// Registers as `"Display/ShoppingListRow"`.
struct ShoppingListRowView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    var body: some View {
        EmptyView()
    }
}

// MARK: - Display-only extensions on the canonical ShoppingUrgency
// (Defined in `Sarvis/UI/Elements/Input/ShoppingItem/ShoppingItemConfig.swift`.)

extension ShoppingUrgency {
    var chipColor: Color {
        switch self {
        case .today:     return Color.orange.opacity(0.82)
        case .nextVisit: return Color.blue.opacity(0.70)
        case .thisWeek:  return Color.teal.opacity(0.70)
        case .someday:   return Color.gray.opacity(0.55)
        }
    }

    var chipBgColor: Color {
        switch self {
        case .today:     return Color.orange.opacity(0.12)
        case .nextVisit: return Color.blue.opacity(0.10)
        case .thisWeek:  return Color.teal.opacity(0.10)
        case .someday:   return Color.gray.opacity(0.08)
        }
    }

    /// Infer urgency from item text (heuristic, MVP only — see file header).
    static func infer(from text: String) -> ShoppingUrgency {
        let lower = text.lowercased()
        if lower.contains("today") || lower.contains("urgent") || lower.contains("asap") {
            return .today
        } else if lower.contains("next visit") || lower.contains("next trip") {
            return .nextVisit
        } else if lower.contains("this week") || lower.contains("week") {
            return .thisWeek
        } else if lower.contains("someday") || lower.contains("eventually") {
            return .someday
        }
        return .nextVisit
    }
}

// MARK: - Standalone shopping card (used by ProcessedView directly)

struct ShoppingItemCard: View {
    let item: TodoItem

    private var urgency: ShoppingUrgency { ShoppingUrgency.infer(from: item.text) }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "cart")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(urgency.chipColor)

            Text(item.text)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Urgency chip
            Text(urgency.label)
                .font(Theme.Typography.meta())
                .foregroundStyle(urgency.chipColor)
                .padding(.horizontal, Theme.Spacing.xs + 2)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(urgency.chipBgColor)
                )
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }
}
