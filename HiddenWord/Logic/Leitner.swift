import Foundation

/// Simple Leitner spaced repetition: six boxes reviewed every 1, 2, 4, 7, 14 and 30 days.
/// Remembered moves a verse up one box; missed sends it back to box 1.
enum Leitner {
    static let intervals = [1, 2, 4, 7, 14, 30]
    static var maxBox: Int { intervals.count }

    static func interval(forBox box: Int) -> Int {
        let clamped = min(max(box, 1), maxBox)
        return intervals[clamped - 1]
    }

    static func apply(remembered: Bool, to verse: Verse, now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let newBox = remembered ? min(max(verse.box, 1) + 1, maxBox) : 1
        verse.box = newBox
        verse.dueDate = calendar.date(byAdding: .day, value: interval(forBox: newBox), to: today) ?? today
        verse.lastReviewed = now
        verse.reviewCount += 1
    }

    /// Due if the due date falls on or before today.
    static func isDue(dueDate: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return true }
        return dueDate < tomorrow
    }

    static func reset(_ verse: Verse, now: Date = .now, calendar: Calendar = .current) {
        verse.box = 1
        verse.dueDate = calendar.startOfDay(for: now)
        verse.lastReviewed = nil
        verse.reviewCount = 0
    }
}
