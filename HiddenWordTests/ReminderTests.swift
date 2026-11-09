import XCTest
@testable import HiddenWord

final class ReminderTests: XCTestCase {
    func testShortVerseIsKeptWhole() {
        XCTAssertEqual(ReminderService.excerpt("He must increase, but I must decrease."),
                       "He must increase, but I must decrease.")
    }

    func testLongVerseEndsAtAPause() {
        let text = "But we have this treasure in jars of clay, to show that the surpassing power belongs to God and not to us, and more words to make it long."
        let e = ReminderService.excerpt(text)
        XCTAssertTrue(e.hasSuffix("…"))
        XCTAssertLessThanOrEqual(e.count, 112)
        XCTAssertTrue(text.hasPrefix(String(e.dropLast())))
    }

    func testDayVerseMatchesAcrossAppAndWidget() {
        let items = (1...5).map { SharedVerses.Item(reference: "V\($0)", text: "t\($0)") }
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(SharedVerses.verse(for: day, in: items), SharedVerses.verse(for: day.addingTimeInterval(3600), in: items))
    }
}

final class ExtraWordTests: XCTestCase {
    func testAddedWordsArePlacedWhereTyped() {
        let r = RecallScorer.score(attempt: "Jesus wept loudly", target: "Jesus wept.")
        XCTAssertEqual(r.extrasAtEnd, ["loudly"])
        let r2 = RecallScorer.score(attempt: "He must greatly increase", target: "He must increase")
        XCTAssertEqual(r2.extrasBefore[2], ["greatly"])
    }
}
