import Foundation
import SwiftData

/// One memory verse. Leitner state lives directly on the model.
@Model
final class Verse {
    var reference: String = ""
    var text: String = ""
    /// Translation label shown next to the reference, e.g. "ESV".
    var translation: String = ""
    /// Leitner box, 1...Leitner.maxBox. New verses start in box 1.
    var box: Int = 1
    /// Start of the day this verse next comes back.
    var dueDate: Date = Date.now
    var lastReviewed: Date?
    var reviewCount: Int = 0
    var createdAt: Date = Date.now
    /// True for verses that came from the bundled starter deck.
    var isStarter: Bool = false

    init(
        reference: String,
        text: String,
        translation: String = "",
        isStarter: Bool = false,
        createdAt: Date = .now
    ) {
        self.reference = reference
        self.text = text
        self.translation = translation
        self.box = 1
        self.dueDate = Calendar.current.startOfDay(for: createdAt)
        self.lastReviewed = nil
        self.reviewCount = 0
        self.createdAt = createdAt
        self.isStarter = isStarter
    }

    /// Ready to come back today. Used only to choose what a session holds; never shown as a count.
    var isReadyToday: Bool { Leitner.isDue(dueDate: dueDate) }

    var displayReference: String {
        translation.isEmpty ? reference : "\(reference) \(translation)"
    }
}
