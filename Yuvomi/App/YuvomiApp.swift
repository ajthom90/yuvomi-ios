import SwiftUI

@main
struct YuvomiApp: App {
    @StateObject private var dependencies = AppDependencies()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(dependencies)
                .environmentObject(dependencies.authStore)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active, dependencies.authStore.isAuthenticated else { return }
                    Task {
                        // Refresh local notifications when returning to the app.
                        if let reminders = try? await dependencies.makeAPI().fetchPendingReminders() {
                            await ReminderNotificationScheduler.sync(reminders: reminders)
                        }
                    }
                }
        }
    }
}
