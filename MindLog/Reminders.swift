import Foundation
import UserNotifications

/// Ежедневное локальное напоминание.
enum Reminders {
    private static let id = "daily-reminder"

    static func enable(minutes: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "Как прошёл день?"
        content.body = "Загляни в дневник и отметь своё состояние."
        content.sound = .default

        var comps = DateComponents()
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        return true
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
