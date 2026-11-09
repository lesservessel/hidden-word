import Foundation
import WidgetKit

/// Hands the deck to the widget and the reminders, and asks the widget to redraw.
enum WidgetSync {
    @MainActor
    static func publish(_ verses: [Verse]) {
        let items = verses.map { SharedVerses.Item(reference: $0.displayReference, text: $0.text) }
        // Reminders carry each day's verse, so re-plan them on every launch.
        ReminderService.refresh(verses: items)
        guard items != SharedVerses.load() else { return }
        SharedVerses.save(items)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
