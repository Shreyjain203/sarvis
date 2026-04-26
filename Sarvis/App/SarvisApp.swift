import SwiftUI
import UserNotifications

@main
struct SarvisApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        NotificationService.shared.registerCategories()
        Task { try? await NotificationService.shared.requestAuthorization() }
        ElementRegistry.shared.registerBuiltIns()
        // Register background task handler before the app finishes launching.
        MorningJob.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(TodoStore.shared)
                .onAppear {
                    // Re-schedule on every launch so bodies stay fresh.
                    MorningJob.scheduleNext()
                    QuoteJob.scheduleDailyPings()
                }
        }
    }
}
