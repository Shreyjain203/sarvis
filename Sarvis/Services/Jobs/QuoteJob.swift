import Foundation
import UserNotifications

/// Schedules two daily motivational-quote notifications using
/// `UNCalendarNotificationTrigger` (deterministic, no background task needed).
///
/// Because iOS cannot compute notification body dynamically at fire time without
/// a Notification Service Extension, the body is baked in at schedule time.
/// Call `scheduleDailyPings()` on every app launch — it tears down the existing
/// pending pings for today and re-schedules them with fresh quote bodies.
@MainActor
enum QuoteJob {

    static let morningID = "com.shrey.sarvis.quote.morning"
    static let afternoonID = "com.shrey.sarvis.quote.afternoon"

    // MARK: - Public API

    /// Removes any pending quote notifications and re-schedules today's two pings
    /// with freshly picked quote bodies baked in.
    static func scheduleDailyPings() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [morningID, afternoonID])

        let morningQuote = QuoteService.shared.random()
        let afternoonQuote = QuoteService.shared.random()

        scheduleQuote(morningQuote, id: morningID, hour: 9, minute: 30)
        scheduleQuote(afternoonQuote, id: afternoonID,
                      hour: afternoonHour(), minute: 0)
    }

    // MARK: - Private helpers

    /// Deterministically picks an afternoon hour in [14, 18) based on the day-of-year,
    /// so the time varies day-to-day but is stable within a single day and doesn't
    /// drift each time the app launches.
    private static func afternoonHour() -> Int {
        let cal = Calendar.current
        let doy = cal.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return 14 + (doy % 5)   // deterministic hour in 14..18
    }

    private static func scheduleQuote(_ quote: Quote?, id: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Daily quote"
        if let q = quote {
            content.body = q.author.map { "\"\(q.text)\" — \($0)" } ?? q.text
        } else {
            content.body = "Keep going."
        }
        content.sound = .default
        // Phase 2.3: use the content-extension category for the custom quote card view.
        content.categoryIdentifier = NotificationService.categoryQuoteMorning
        if let q = quote {
            content.userInfo = [
                "quote":       q.text,
                "attribution": q.author.map { "— \($0)" } ?? ""
            ]
        }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("QuoteJob: failed to schedule \(id):", error)
            }
        }
    }
}
