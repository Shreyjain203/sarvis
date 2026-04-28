import SwiftUI

/// Notification UI for the `task.reminder` category.
/// Shows: importance dot, serif title, body text, due-time chip.
struct TaskReminderView: View {
    let title: String
    let bodyText: String
    let importance: String          // "low" | "med" | "high" | "critical"
    let dueAtISO: String?           // ISO 8601 string or nil

    private var formattedDue: String? {
        guard let iso = dueAtISO else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)
        if date == nil {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }
        guard let date else { return nil }

        let display = DateFormatter()
        display.doesRelativeDateFormatting = true
        display.dateStyle = .short
        display.timeStyle = .short
        return display.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ExtensionTheme.Spacing.sm) {

            // Importance dot row
            HStack(spacing: ExtensionTheme.Spacing.xs) {
                Circle()
                    .fill(ExtensionTheme.Palette.dot(for: importance))
                    .frame(width: 10, height: 10)
                Text(importanceLabel)
                    .font(ExtensionTheme.Typography.meta())
                    .foregroundStyle(ExtensionTheme.Palette.muted)
            }

            // Serif title
            Text(title)
                .font(ExtensionTheme.Typography.sectionTitle())
                .foregroundStyle(ExtensionTheme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            // Body text
            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(ExtensionTheme.Typography.body())
                    .foregroundStyle(ExtensionTheme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Due-time chip
            if let due = formattedDue {
                HStack(spacing: ExtensionTheme.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(due)
                        .font(ExtensionTheme.Typography.chip())
                }
                .foregroundStyle(ExtensionTheme.Palette.ink)
                .padding(.horizontal, ExtensionTheme.Spacing.sm)
                .padding(.vertical, ExtensionTheme.Spacing.xs)
                .background(
                    Capsule().fill(ExtensionTheme.Palette.card)
                )
                .overlay(
                    Capsule().strokeBorder(ExtensionTheme.Palette.hairline, lineWidth: 0.5)
                )
            }
        }
        .padding(ExtensionTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importanceLabel: String {
        switch importance {
        case "low":      return "Low priority"
        case "high":     return "High priority"
        case "critical": return "Critical"
        default:         return "Medium priority"
        }
    }
}
