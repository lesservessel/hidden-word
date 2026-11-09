import Foundation
import UserNotifications

/// The daily reminder: local notifications only, no server, no push.
///
/// Instead of one repeating "come practice" line, the next two weeks are scheduled one day
/// at a time, each carrying that day's verse (the same one the home screen and widget show).
/// The schedule is refreshed whenever the app is opened or the verses change.
enum ReminderService {
    private static let prefix = "hiddenword.daily."
    private static let legacyIdentifier = "hiddenword.daily-reminder"
    private static let days = 14

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "reminder.enabled") }
    static var hour: Int { UserDefaults.standard.object(forKey: "reminder.hour") as? Int ?? 7 }
    static var minute: Int { UserDefaults.standard.object(forKey: "reminder.minute") as? Int ?? 0 }

    /// Asks for permission if needed, then schedules. Returns false if denied.
    static func enable(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        schedule(hour: hour, minute: minute)
        return true
    }

    static func schedule(hour: Int, minute: Int, verses: [SharedVerses.Item] = SharedVerses.load()) {
        let center = UNUserNotificationCenter.current()
        clear()

        let calendar = Calendar.current
        let now = Date.now
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { continue }

            let content = UNMutableNotificationContent()
            if let verse = SharedVerses.verse(for: day, in: verses) {
                content.title = verse.reference
                content.body = excerpt(verse.text)
            } else {
                content.title = "Hidden Word"
                content.body = "A quiet minute with the Word."
            }
            content.sound = .default

            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: prefix + "\(offset)", content: content, trigger: trigger))
        }
    }

    /// Re-plan the next two weeks if reminders are on. Cheap; called on launch and on edits.
    static func refresh(verses: [SharedVerses.Item]) {
        guard isEnabled else { return }
        schedule(hour: hour, minute: minute, verses: verses)
    }

    static func disable() { clear() }

    private static func clear() {
        let ids = [legacyIdentifier] + (0..<days).map { prefix + "\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// The first words of the verse, ending at a natural pause when there is one.
    static func excerpt(_ text: String, limit: Int = 110) -> String {
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit))
        if let cut = head.lastIndex(where: { ",;:.".contains($0) }), head.distance(from: head.startIndex, to: cut) > 50 {
            return String(head[...cut]).trimmingCharacters(in: .punctuationCharacters) + "…"
        }
        return (head.split(separator: " ").dropLast().joined(separator: " ")) + "…"
    }
}
