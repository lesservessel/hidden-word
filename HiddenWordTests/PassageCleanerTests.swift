import XCTest
@testable import HiddenWord

/// Every format the paste cleaner has been fixed for. If a rule change breaks one, this fails.
final class PassageCleanerTests: XCTestCase {
    private func clean(_ s: String) -> PassageCleaner.Result { PassageCleaner.clean(s) }
    private func noDigits(_ s: String, allowing allowed: Set<String> = []) -> Bool {
        let numbers = s.split(whereSeparator: { !$0.isNumber }).map(String.init)
        return numbers.allSatisfy { allowed.contains($0) }
    }

    func testWebsitePasteWithBracketedNumbersAndHeadings() {
        let r = clean(Samples.jamesWebsite)
        XCTAssertEqual(r.reference, "James 1:1-5")
        XCTAssertEqual(r.translation, "ESV")
        XCTAssertTrue(r.text.hasPrefix("James, a servant of God"))
        XCTAssertFalse(r.text.contains("Testing of Your Faith"))
        XCTAssertFalse(r.text.contains("["))
        XCTAssertEqual(r.verses.map(\.number), [1, 2, 3, 4, 5])
    }

    func testBibleGatewayPasteDropsNumbersFootnotesAndNotes() {
        let r = clean(Samples.jamesBibleGateway)
        XCTAssertTrue(noDigits(r.text), r.text)
        XCTAssertFalse(r.text.contains("[a]"))
        XCTAssertFalse(r.text.contains("Footnotes"))
        XCTAssertTrue(r.text.contains("a servant of God"))
        XCTAssertEqual(r.verses.count, 27)
    }

    func testFootnoteLettersStuckToWordsMatchBracketedVersion() {
        XCTAssertEqual(clean(Samples.jamesGlued).text, clean(Samples.jamesBibleGateway).text)
    }

    func testSelectionStartingMidVerse() {
        let r = clean(Samples.midVerse)
        XCTAssertTrue(noDigits(r.text, allowing: ["4", "000"]), r.text)
        XCTAssertEqual(r.verses.map(\.number), [36, 37, 38])
    }

    func testChapterNumberStandsInForVerseOne() {
        let r = clean(Samples.psalmChapterNumber)
        XCTAssertEqual(r.reference, "Psalm 23:1-2")
        XCTAssertTrue(r.text.contains("The LORD is my shepherd"))
    }

    func testMultiChapterPasteRemovesAllVerseNumbers() {
        let r = clean(Samples.multiChapter)
        XCTAssertTrue(noDigits(r.text), r.text)
        XCTAssertTrue(r.verses.isEmpty)
    }

    func testReferenceAfterDash() {
        let r = clean(Samples.dashReference)
        XCTAssertEqual(r.reference, "Matthew 11:28")
        XCTAssertEqual(r.translation, "ESV")
        XCTAssertFalse(r.text.contains("Matthew"))
    }

    func testSiteButtonLabelsDropped() {
        XCTAssertFalse(clean(Samples.readMore).text.contains("Read full chapter"))
    }

    func testRealNumbersInTheTextAreKept() {
        let r = clean("and he was there 3 days and 40 nights, and 12 men went with him.")
        XCTAssertEqual(r.text, "and he was there 3 days and 40 nights, and 12 men went with him.")
    }

    func testYouVersionShareFormat() {
        let r = clean("For God so loved the world, that he gave his only Son.\n\nJohn 3:16 ESV\n\nhttps://bible.com/bible/59/jhn.3.16.ESV")
        XCTAssertEqual(r.reference, "John 3:16")
        XCTAssertEqual(r.translation, "ESV")
        XCTAssertEqual(r.text, "For God so loved the world, that he gave his only Son.")
    }

    func testApostrophesKeepTheirS() {
        let r = clean("the Lord’s Prayer, he can’t, God’s word.")
        XCTAssertEqual(r.text, "the Lord’s Prayer, he can’t, God’s word.")
    }

    func testGarbledQuotesRepaired() {
        XCTAssertTrue(clean(Samples.garbledMac).text.contains("person’s"))
        XCTAssertTrue(clean(Samples.garbledWindows).text.contains("person’s"))
        XCTAssertFalse(clean(Samples.garbledMac).text.contains("‚Ä"))
    }

    func testSuperscriptVerseNumbers() {
        let r = clean("²Count it all joy, my brothers, ³for you know that the testing of your faith produces steadfastness.")
        XCTAssertTrue(noDigits(r.text))
        XCTAssertEqual(r.verses.map(\.number), [2, 3])
    }
}
