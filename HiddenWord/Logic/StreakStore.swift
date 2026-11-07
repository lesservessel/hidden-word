import Foundation
import Observation

/// Daily practice streak, persisted in UserDefaults.
@Observable
final class StreakStore {
    private(set) var current: Int
    private(set) var best: Int
    private(set) var lastDay: Date?

    private let defaults: UserDefaults

    private enum Keys {
        static let current = "streak.current"
        static let best = "streak.best"
        static let lastDay = "streak.lastDay"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.current = defaults.integer(forKey: Keys.current)
        self.best = defaults.integer(forKey: Keys.best)
        let stamp = defaults.double(forKey: Keys.lastDay)
        self.lastDay = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    /// The streak as of today: it is broken if the last practice was before yesterday.
    func displayStreak(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let lastDay else { return 0 }
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDay), to: today).day ?? 0
        return days <= 1 ? current : 0
    }

    func practicedToday(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let lastDay else { return false }
        return calendar.isDate(lastDay, inSameDayAs: now)
    }

    func recordPractice(now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        if let lastDay {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDay), to: today).day ?? 0
            if days == 0 { return }
            current = days == 1 ? current + 1 : 1
        } else {
            current = 1
        }
        lastDay = today
        best = max(best, current)
        save()
    }

    func reset() {
        current = 0
        best = 0
        lastDay = nil
        save()
    }

    private func save() {
        defaults.set(current, forKey: Keys.current)
        defaults.set(best, forKey: Keys.best)
        defaults.set(lastDay?.timeIntervalSince1970 ?? 0, forKey: Keys.lastDay)
    }
}
