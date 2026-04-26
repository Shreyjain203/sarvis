import Foundation
import BackgroundTasks
import UserNotifications

/// Manages the daily morning briefing background job.
///
/// The job fetches today's news, asks the LLM for a digest, persists it via
/// `DailyArtifactStore`, then fires a "Today's briefing" notification with the
/// summary baked into the body at schedule time.
///
/// iOS scheduling notes:
/// - `BGAppRefreshTask` is best-effort; the OS may fire it later than requested.
/// - Register BEFORE the app finishes launching (call `register()` from `App.init()`).
/// - Call `scheduleNext()` after every launch and after the task completes.
@MainActor
enum MorningJob {

    static let taskID = "com.shrey.sarvis.morning"
    static let notificationID = "com.shrey.sarvis.morning.notification"

    // MARK: - BGTaskScheduler registration

    /// Registers the background task handler with the system.
    /// Must be called before the app finishes launching (`App.init()` is the right place).
    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleTask(refreshTask)
        }
    }

    // MARK: - Scheduling

    /// Submits a `BGAppRefreshTaskRequest` targeting the next 7 AM local time.
    /// The OS will fire it at its earliest convenience at or after that time.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = nextSevenAM()
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("MorningJob: failed to schedule BGAppRefreshTask:", error)
        }
    }

    // MARK: - Task handler

    private static func handleTask(_ task: BGAppRefreshTask) {
        // Schedule next occurrence immediately so we don't miss tomorrow.
        scheduleNext()

        let workTask = Task {
            do {
                // 1. Fetch / refresh today's news.
                let articles = try await NewsService.shared.refreshToday()
                let topArticles = Array(articles.prefix(7))

                // 2. Build prompt, substituting {{articles}} placeholder.
                let promptBody = PromptLibrary.body(
                    for: "news_summary",
                    fallback: "Summarise these news articles briefly:\n{{articles}}"
                )
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let articlesJSON = (try? encoder.encode(topArticles))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                let filledPrompt = promptBody
                    .replacingOccurrences(of: "{{articles}}", with: articlesJSON)

                // 3. Ask the LLM for a summary.
                let llm = LLMService()
                let summary = await llm.ask(
                    systemPrompt: "You are a concise news summariser for a personal assistant.",
                    prompt: filledPrompt
                ) ?? "Could not generate summary."

                // 4. Persist the summary.
                struct NewsSummary: Codable {
                    let date: Date
                    let summary: String
                    let articleCount: Int
                }
                let artifact = NewsSummary(
                    date: Date(),
                    summary: summary,
                    articleCount: topArticles.count
                )
                DailyArtifactStore.shared.write(artifact, folder: "news", date: Date())

                // 5. Fire the briefing notification.
                await scheduleNotification(body: summary)

                task.setTaskCompleted(success: true)
            } catch {
                print("MorningJob: task failed:", error)
                task.setTaskCompleted(success: false)
            }
        }

        // If iOS revokes our background time, cancel and mark failed.
        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Notification

    private static func scheduleNotification(body: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Today's briefing"
        content.body = body
        content.sound = .default

        // Fire ~immediately (1 second from now — background tasks have no precise time).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("MorningJob: failed to schedule notification:", error)
        }
    }

    // MARK: - Date helpers

    private static func nextSevenAM() -> Date {
        var components = Calendar.current.dateComponents(
            [.year, .month, .day], from: Date()
        )
        components.hour = 7
        components.minute = 0
        components.second = 0

        guard let today7AM = Calendar.current.date(from: components) else {
            return Date(timeIntervalSinceNow: 8 * 3600)
        }

        if today7AM > Date() {
            return today7AM
        }
        // Already past 7 AM — target tomorrow.
        return Calendar.current.date(byAdding: .day, value: 1, to: today7AM) ?? today7AM
    }
}
