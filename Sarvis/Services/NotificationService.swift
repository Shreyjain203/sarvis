import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    static let categoryID = "TODO_REMINDER"
    static let doneActionID = "ACTION_DONE"
    static let snoozeActionID = "ACTION_SNOOZE"
    static let snoozeMinutes = 10

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func registerCategories() {
        let done = UNNotificationAction(
            identifier: Self.doneActionID,
            title: "Mark Done",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "Snooze \(Self.snoozeMinutes) min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [done, snooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    @discardableResult
    func schedule(_ todo: TodoItem, at date: Date) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = todo.isSensitive ? "Reminder (sensitive)" : "Reminder"
        content.body = todo.text
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = ["todoID": todo.id.uuidString]

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let id = todo.notificationID ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
        return id
    }

    /// Lightweight overload for scheduling a notification from raw title/body/date
    /// without needing a full `TodoItem`. Used by `ClassifierService` to fire
    /// notifications inferred from LLM output.
    @discardableResult
    func schedule(title: String, body: String, at date: Date) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryID

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
        return id
    }

    func cancel(_ id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let idStr = info["todoID"] as? String,
              let id = UUID(uuidString: idStr) else { return }

        await MainActor.run {
            switch response.actionIdentifier {
            case Self.doneActionID:
                TodoStore.shared.toggleDone(id)
            case Self.snoozeActionID:
                self.snooze(id: id)
            default:
                break
            }
        }
    }

    private func snooze(id: UUID) {
        guard var item = TodoStore.shared.items.first(where: { $0.id == id }) else { return }
        let newDate = Date().addingTimeInterval(Double(Self.snoozeMinutes) * 60)
        item.dueAt = newDate
        Task { [item, newDate] in
            do {
                var draft = item
                draft.notificationID = try await schedule(draft, at: newDate)
                let final = draft
                await MainActor.run { TodoStore.shared.update(final) }
            } catch {
                print("Snooze failed:", error)
            }
        }
    }
}
