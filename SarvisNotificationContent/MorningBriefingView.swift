import SwiftUI

/// Notification UI for the `news.briefing` category.
/// Shows: date header, headline summary, 2–3 bullet headlines.
struct MorningBriefingView: View {
    let title: String
    let headline: String
    let bulletsRaw: String   // newline-separated bullet strings

    private var bullets: [String] {
        bulletsRaw
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ExtensionTheme.Spacing.sm) {

            // Date header
            Text(dateString.uppercased())
                .font(ExtensionTheme.Typography.meta())
                .foregroundStyle(ExtensionTheme.Palette.muted)
                .tracking(1.2)

            // Section title (e.g. "Today's briefing")
            Text(title)
                .font(ExtensionTheme.Typography.sectionTitle())
                .foregroundStyle(ExtensionTheme.Palette.ink)

            // Divider
            Rectangle()
                .fill(ExtensionTheme.Palette.hairline)
                .frame(height: 0.5)
                .padding(.vertical, ExtensionTheme.Spacing.xs)

            // Headline summary
            Text(headline)
                .font(ExtensionTheme.Typography.bodyEmphasis())
                .foregroundStyle(ExtensionTheme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            // Bullet headlines
            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: ExtensionTheme.Spacing.xs) {
                    ForEach(bullets.prefix(3), id: \.self) { bullet in
                        HStack(alignment: .top, spacing: ExtensionTheme.Spacing.xs) {
                            Text("•")
                                .font(ExtensionTheme.Typography.meta())
                                .foregroundStyle(ExtensionTheme.Palette.muted)
                            Text(bullet)
                                .font(ExtensionTheme.Typography.meta())
                                .foregroundStyle(ExtensionTheme.Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(ExtensionTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
