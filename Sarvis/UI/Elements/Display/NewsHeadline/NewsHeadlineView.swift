import SwiftUI

/// A news headline card — title, source, publishedAt, tappable URL.
/// Registers as `"Display/NewsHeadline"`.
struct NewsHeadlineView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    var body: some View {
        EmptyView()
    }
}

// MARK: - Standalone news headline card (used by ProcessedView directly)

struct NewsHeadlineCard: View {
    let article: NewsArticle

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Link(destination: URL(string: article.url) ?? URL(string: "https://apple.com")!) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(article.title)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if let desc = article.description, !desc.isEmpty {
                    Text(desc)
                        .font(Theme.Typography.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    if let source = article.source, !source.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "newspaper")
                                .font(.system(size: 9))
                            Text(source)
                        }
                        .foregroundStyle(Theme.Palette.muted)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(Self.dateFormatter.string(from: article.publishedAt))
                    }
                    .foregroundStyle(Theme.Palette.muted)
                }
                .font(Theme.Typography.meta())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
        }
    }
}
