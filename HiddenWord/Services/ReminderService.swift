import Foundation
import UserNotifications

/// One repeating local notification at a user-chosen time. No server, no push.
enum ReminderService {
    static let identifier = "hiddenword.daily-reminder"

    /// Asks for permission if needed, then schedules the reminder. Returns false if denied.
    static func enable(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            granted = false
        }
        guard granted else { return false }
        schedule(hour: hour, minute: minute)
        return true
    }

    static func schedule(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Hidden Word"
        content.body = "A few minutes in the Word. Your verses are waiting."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
