// Keep identical to HiddenWord/Shared/SharedVerses.swift (the widget is a separate target).
import Foundation

/// The verses the widget can see, written by the app into a shared App Group.
/// The widget picks the day's verse with the same rule as the app's home screen.
enum SharedVerses {
    static let appGroup = "group.com.lesservessel.HiddenWord"
    private static let key = "verses.v1"

    struct Item: Codable, Hashable {
        let reference: String
        let text: String
    }

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func save(_ items: [Item]) {
        guard let defaults, let data = try? JSONEncoder().encode(Array(items.prefix(400))) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> [Item] {
        guard let data = defaults?.data(forKey: key),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return [] }
        return items
    }

    /// Same verse all day, rotating through the list one per day.
    static func verse(for date: Date, in items: [Item], calendar: Calendar = .current) -> Item? {
        guard !items.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return items[day % items.count]
    }

    static let fallback = Item(reference: "Psalm 119:11",
                               text: "I have stored up your word in my heart, that I might not sin against you.")
}
