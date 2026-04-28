import SwiftUI

/// Tap-to-expand card for one Gmail message in Library → Email.
/// Mirrors the visual idiom of `NoteCard` / `ShoppingListRow` — themedCard
/// with a small palette dot and meta line. Expanded state reveals the
/// stored snippet + full sender string.
struct EmailItemRow: View {
    enum Palette {
        case important
        case fyi
        case promo

        var dot: Color {
            switch self {
            case .important: return Color.orange.opacity(0.85)
            case .fyi:       return Color.blue.opacity(0.7)
            case .promo:     return Color.gray.opacity(0.55)
            }
        }
    }

    let item: EmailItem
    let palette: Palette
    let isExpanded: Bool
    let onTap: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Circle()
                        .fill(palette.dot)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.subject)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(Theme.Palette.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(shortSender)
                            .font(Theme.Typography.meta())
                            .foregroundStyle(Theme.Palette.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(Self.dateFormatter.string(from: item.receivedAt))
                        .font(Theme.Typography.meta())
                        .foregroundStyle(Theme.Palette.muted)
                        .padding(.top, 2)
                }

                if isExpanded {
                    Divider().background(Theme.Palette.hairline)
                    if !item.snippet.isEmpty {
                        Text(item.snippet)
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(item.sender)
                        .font(Theme.Typography.meta())
                        .foregroundStyle(Theme.Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Show just the human name part of "Name <addr@host>" if present.
    private var shortSender: String {
        let raw = item.sender
        if let openIdx = raw.firstIndex(of: "<") {
            return raw[raw.startIndex..<openIdx]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
        }
        return raw
    }
}

/// Compact row for an extracted action item (e.g., "Reply to recruiter").
struct EmailActionRow: View {
    let action: EmailAction

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Theme.Palette.muted)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.text)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let due = action.dueAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(Self.dateFormatter.string(from: due))
                    }
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }
}
