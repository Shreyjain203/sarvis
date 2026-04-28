import SwiftUI
import UserNotifications

// MARK: - Payload contract
//
// Each notification category expects the following userInfo keys:
//
// task.reminder
//   "importance"  String  "low" | "med" | "high" | "critical"  (default "med")
//   "dueAt"       String  ISO 8601 date string, e.g. "2026-04-27T15:00:00Z"
//   (title and body come from UNNotificationContent.title / .body)
//
// news.briefing
//   "headline"    String  One-line summary sentence
//   "bullets"     String  Newline-separated list of 2–3 bullet headlines
//   (title comes from UNNotificationContent.title, e.g. "Today's briefing")
//
// quote.morning
//   "quote"       String  The quote body text
//   "attribution" String  Attribution line, e.g. "— Marcus Aurelius"
//   (title comes from UNNotificationContent.title, e.g. "Daily quote")

/// Top-level SwiftUI view that dispatches to the correct category template.
struct NotificationContentView: View {
    let notification: UNNotification

    private var category: String {
        notification.request.content.categoryIdentifier
    }
    private var info: [AnyHashable: Any] {
        notification.request.content.userInfo
    }
    private var title: String    { notification.request.content.title }
    private var bodyText: String { notification.request.content.body }

    var body: some View {
        ZStack {
            ExtensionTheme.Palette.paper.ignoresSafeArea()

            switch category {
            case "task.reminder":
                TaskReminderView(
                    title: title,
                    bodyText: bodyText,
                    importance: info["importance"] as? String ?? "med",
                    dueAtISO: info["dueAt"] as? String
                )

            case "news.briefing":
                MorningBriefingView(
                    title: title,
                    headline: info["headline"] as? String ?? bodyText,
                    bulletsRaw: info["bullets"] as? String ?? ""
                )

            case "quote.morning":
                QuoteCardView(
                    quote: info["quote"] as? String ?? bodyText,
                    attribution: info["attribution"] as? String ?? ""
                )

            default:
                // Fallback: plain text for unknown categories
                VStack(alignment: .leading, spacing: ExtensionTheme.Spacing.sm) {
                    Text(title)
                        .font(ExtensionTheme.Typography.sectionTitle())
                    Text(bodyText)
                        .font(ExtensionTheme.Typography.body())
                        .foregroundStyle(ExtensionTheme.Palette.inkSoft)
                }
                .padding(ExtensionTheme.Spacing.md)
            }
        }
    }
}
