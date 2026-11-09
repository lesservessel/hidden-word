import Foundation
import WidgetKit

/// Hands the deck to the widget and asks it to redraw.
enum WidgetSync {
    @MainActor
    static func publish(_ verses: [Verse]) {
        let items = verses.map { SharedVerses.Item(reference: $0.displayReference, text: $0.text) }
        guard items != SharedVerses.load() else { return }
        SharedVerses.save(items)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
