import Foundation
import SwiftData

/// The bundled starter deck: twelve "vessel" verses.
///
/// To swap translations (for example to a public-domain text such as the KJV or WEB,
/// or after you obtain a license), replace `translation` and the `verses` array below.
/// Nothing else in the app depends on the specific wording.
///
/// Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®),
/// copyright © 2001 by Crossway, a publishing ministry of Good News Publishers.
/// Used by permission. All rights reserved.
enum StarterDeck {
    struct Entry {
        let reference: String
        let text: String
    }

    static let translation = "ESV"

    static let verses: [Entry] = [
        Entry(reference: "Isaiah 64:8",
              text: "But now, O LORD, you are our Father; we are the clay, and you are our potter; we are all the work of your hand."),
        Entry(reference: "Jeremiah 18:4",
              text: "And the vessel he was making of clay was spoiled in the potter’s hand, and he reworked it into another vessel, as it seemed good to the potter to do."),
        Entry(reference: "Romans 9:21",
              text: "Has the potter no right over the clay, to make out of the same lump one vessel for honorable use and another for dishonorable use?"),
        Entry(reference: "2 Corinthians 4:7",
              text: "But we have this treasure in jars of clay, to show that the surpassing power belongs to God and not to us."),
        Entry(reference: "2 Corinthians 12:9",
              text: "But he said to me, “My grace is sufficient for you, for my power is made perfect in weakness.” Therefore I will boast all the more gladly of my weaknesses, so that the power of Christ may rest upon me."),
        Entry(reference: "John 3:30",
              text: "He must increase, but I must decrease."),
        Entry(reference: "Genesis 1:27",
              text: "So God created man in his own image, in the image of God he created him; male and female he created them."),
        Entry(reference: "2 Timothy 2:21",
              text: "Therefore, if anyone cleanses himself from what is dishonorable, he will be a vessel for honorable use, set apart as holy, useful to the master of the house, ready for every good work."),
        Entry(reference: "Philippians 2:7",
              text: "but emptied himself, by taking the form of a servant, being born in the likeness of men."),
        Entry(reference: "Ephesians 2:10",
              text: "For we are his workmanship, created in Christ Jesus for good works, which God prepared beforehand, that we should walk in them."),
        Entry(reference: "Romans 8:29",
              text: "For those whom he foreknew he also predestined to be conformed to the image of his Son, in order that he might be the firstborn among many brothers."),
        Entry(reference: "Matthew 5:16",
              text: "In the same way, let your light shine before others, so that they may see your good works and give glory to your Father who is in heaven."),
    ]

    private static let seededKey = "didSeedStarterDeck"

    static var wasSeeded: Bool { UserDefaults.standard.bool(forKey: seededKey) }

    /// Records that the starter deck was offered, without adding it.
    static func markSeeded() { UserDefaults.standard.set(true, forKey: seededKey) }

    /// Inserts the starter deck once, on first launch.
    static func seedIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }
        insertMissing(context: context)
        defaults.set(true, forKey: seededKey)
    }

    /// Adds any starter verse whose reference is not already in the deck.
    /// Returns how many were added.
    @discardableResult
    static func insertMissing(context: ModelContext) -> Int {
        let existing = (try? context.fetch(FetchDescriptor<Verse>())) ?? []
        let references = Set(existing.map { $0.reference })
        let base = Date.now
        var added = 0
        for (index, entry) in verses.enumerated() where !references.contains(entry.reference) {
            let verse = Verse(
                reference: entry.reference,
                text: entry.text,
                translation: translation,
                isStarter: true,
                createdAt: base.addingTimeInterval(Double(index))
            )
            context.insert(verse)
            added += 1
        }
        try? context.save()
        return added
    }
}
