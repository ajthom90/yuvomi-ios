import Foundation
import UserNotifications

/// Schedules local notifications for pending Yuvomi reminders (no APNs required).
@MainActor
enum ReminderNotificationScheduler {
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Replaces previously scheduled Yuvomi reminder notifications with the current pending set.
    static func sync(reminders: [ReminderItem]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.filter { $0.identifier.hasPrefix("yuvomi-reminder-") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let allowed = await requestAuthorizationIfNeeded()
        guard allowed else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatter2 = ISO8601DateFormatter()
        formatter2.formatOptions = [.withInternetDateTime]
        let local = DateFormatter()
        local.calendar = Calendar(identifier: .gregorian)
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = TimeZone.current
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        for item in reminders where !item.dismissed {
            let date =
                formatter.date(from: item.remindAt)
                ?? formatter2.date(from: item.remindAt)
                ?? local.date(from: item.remindAt)
            guard let date, date > Date().addingTimeInterval(-60) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Yuvomi reminder"
            content.body = item.displayTitle
            content.sound = .default
            content.userInfo = [
                "entity_type": item.entityType,
                "entity_id": item.entityId,
                "reminder_id": item.id,
            ]

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "yuvomi-reminder-\(item.id)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
