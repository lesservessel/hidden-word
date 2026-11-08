import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Turns text copied from a Bible website or app into just the words of the passage.
///
/// Handles the common copy formats:
/// - A reference line first or last ("James 1", "John 3:16 ESV", "Romans 8:28-30").
/// - A translation tag at the end ("(ESV)", "ESV").
/// - Verse numbers as "[2]", superscripts ("²"), glued ("2Count") or plain ("2 Count").
/// - Footnote and cross-reference markers ("[a]", "(A)").
/// - Section headings ("Testing of Your Faith") and share links.
enum PassageCleaner {
    struct Result: Equatable {
        var text: String
        var reference: String?
        var translation: String?
    }

    /// Returns true for a correctly spelled word. Used to spot footnote letters that lost their
    /// brackets and stuck to a word ("servanta" -> "servant"). Nil skips that step.
    typealias SpellCheck = (String) -> Bool

    static func clean(_ raw: String, isWord: SpellCheck? = defaultSpellCheck) -> Result {
        var translation: String?
        var reference: String?

        var lines = repairEncoding(raw)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map(dropDashBeforeReference)
            .filter { !$0.isEmpty && !isLink($0) && !isSiteLeftover($0) }

        // Bible Gateway appends its notes: drop everything from "Footnotes" / "Cross references" on.
        if let notes = lines.firstIndex(where: { ["footnotes", "cross references"].contains($0.lowercased()) }) {
            lines.removeSubrange(notes...)
        }

        // Translation tag at the very end: "... world. (ESV)" or a last line "ESV".
        if var last = lines.last {
            if let tag = firstMatch(#"\s*\(([A-Z][A-Z0-9]{1,6})\)\s*$"#, in: last) {
                translation = tag.groups[0]
                last.removeSubrange(tag.range)
                lines[lines.count - 1] = last
                if last.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeLast() }
            } else if isTranslationTag(last), lines.count > 1 {
                translation = last
                lines.removeLast()
            }
        }

        // Reference on its own first or last line.
        var referenceLine: String?
        if lines.count > 1, let first = lines.first, isReferenceLine(first) {
            referenceLine = first
            lines.removeFirst()
        } else if lines.count > 1, let last = lines.last, isReferenceLine(last) {
            referenceLine = last
            lines.removeLast()
        }
        if let line = referenceLine {
            let (ref, tag) = splitTranslation(line)
            reference = ref
            if translation == nil { translation = tag }
        }

        // Section headings.
        lines.removeAll(where: isHeading)

        lines = lines.map { line in
            var l = line
            // Footnote and cross-reference markers: [a], [bc], (A), (BC).
            l = replace(#"\[[a-z]{1,2}\]|\([A-Z]{1,2}\)"#, in: l, with: "")
            // Superscript verse numbers.
            l = replace("[\u{2070}\u{00B9}\u{00B2}\u{00B3}\u{2074}-\u{2079}]+", in: l, with: " ")
            return l
        }

        // Bracketed verse numbers: [12]
        var numbers: [Int] = []
        lines = lines.map { line in
            numbers += allMatches(#"\[(\d{1,3})\]"#, in: line).compactMap { Int($0.groups[0]) }
            return replace(#"\[\d{1,3}\]"#, in: line, with: " ")
        }

        // Bare verse numbers ("2 Count", "2Count").
        var spansChapters = false
        if numbers.isEmpty {
            let stripped = stripBareVerseNumbers(lines)
            lines = stripped.lines
            numbers = stripped.verses
            spansChapters = stripped.spansChapters
        }

        var text = tidy(lines.joined(separator: " "))
        if let isWord { text = unstickFootnoteLetters(text, isWord: isWord) }

        // "James 1" + verses 1...27 -> "James 1:1-27"
        if let ref = reference, !ref.contains(":"), !spansChapters,
           let lo = numbers.min(), let hi = numbers.max() {
            reference = lo == hi ? "\(ref):\(lo)" : "\(ref):\(lo)-\(hi)"
        }

        return Result(text: text, reference: reference, translation: translation)
    }

    // MARK: - Garbled characters

    /// Fixes text whose UTF-8 bytes were read in the wrong encoding, which turns curly quotes
    /// and dashes into junk: ’ -> "‚Äô" (Mac Roman) or "â€™" (Windows), “ -> "‚Äú", — -> "‚Äî".
    static func repairEncoding(_ text: String) -> String {
        let attempts: [(marker: String, encoding: String.Encoding)] = [
            ("‚Ä", .macOSRoman), ("â€", .windowsCP1252), ("Ã", .windowsCP1252),
        ]
        for (marker, encoding) in attempts where text.contains(marker) {
            // Whole string: re-encode to the bytes it came from, then read them as UTF-8.
            if let bytes = text.data(using: encoding),
               let fixed = String(data: bytes, encoding: .utf8) {
                return fixed
            }
        }
        // Mixed text that can't round-trip: fix the common sequences one by one.
        var fixed = text
        let table: [(String, String)] = [
            ("‚Äô", "’"), ("‚Äò", "‘"), ("‚Äú", "“"), ("‚Äù", "”"), ("‚Äî", "—"), ("‚Äì", "–"), ("‚Ä¶", "…"), ("¬†", " "),
            ("â€™", "’"), ("â€˜", "‘"), ("â€œ", "“"), ("â€\u{FFFD}", "”"), ("â€\u{9D}", "”"), ("â€”", "—"), ("â€“", "–"), ("â€¦", "…"),
            ("â€", "”"),  // closing quote whose last byte was dropped; must come after the others
        ]
        for (bad, good) in table { fixed = fixed.replacingOccurrences(of: bad, with: good) }
        return fixed
    }

    // MARK: - Line tests

    static func isReferenceLine(_ line: String) -> Bool {
        guard line.count <= 40 else { return false }
        // Optional 1-3 prefix, a book name, a chapter, optional :verse(-verse), optional tag.
        let pattern = #"^([1-3]\s?)?[A-Za-z][A-Za-z .]*\s\d{1,3}(:\d{1,3}([-–]\d{1,3})?)?(\s+\(?[A-Z][A-Z0-9]{1,6}\)?)?$"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    static func isHeading(_ line: String) -> Bool {
        let words = line.split(separator: " ").map(String.init)
        guard (1...8).contains(words.count),
              let last = line.last, !".,;:!?\"'”’)…—-".contains(last),
              !line.contains(where: \.isNumber)
        else { return false }
        let small: Set<String> = ["a", "an", "and", "as", "at", "by", "for", "from", "in",
                                  "into", "of", "on", "or", "the", "to", "with"]
        return words.enumerated().allSatisfy { index, word in
            let letters = word.trimmingCharacters(in: .punctuationCharacters)
            guard let first = letters.first else { return true }
            if first.isUppercase { return true }
            return index > 0 && small.contains(letters.lowercased())
        }
    }

    /// "— Matthew 11:28 ESV" -> "Matthew 11:28 ESV". Lines that aren't references are untouched.
    private static func dropDashBeforeReference(_ line: String) -> String {
        guard let first = line.first, "—–-~".contains(first) else { return line }
        let rest = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        return isReferenceLine(rest) ? rest : line
    }

    /// Button and link labels that Bible sites copy along with the text.
    private static let siteLeftovers: Set<String> = [
        "read full chapter", "read more", "read chapter", "show more", "see more",
        "copy", "copy link", "share", "listen", "audio", "play", "highlight", "bookmark",
        "compare", "compare translations", "note", "notes", "previous", "next",
        "previous chapter", "next chapter", "in context", "full chapter", "parallel",
    ]

    private static func isSiteLeftover(_ line: String) -> Bool {
        let key = line.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return siteLeftovers.contains(key)
    }

    private static func isLink(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasPrefix("http") || lower.hasPrefix("www.") || lower.contains("bible.com/")
    }

    private static func isTranslationTag(_ line: String) -> Bool {
        line.range(of: #"^\(?[A-Z][A-Z0-9]{1,6}\)?$"#, options: .regularExpression) != nil
    }

    /// "John 3:30 ESV" -> ("John 3:30", "ESV")
    private static func splitTranslation(_ line: String) -> (String, String?) {
        if let m = firstMatch(#"\s+\(?([A-Z][A-Z0-9]{1,6})\)?$"#, in: line) {
            var ref = line
            ref.removeSubrange(m.range)
            return (ref, m.groups[0])
        }
        return (line, nil)
    }

    // MARK: - Verse numbers

    /// Removes verse numbers written as plain digits, keeping numbers that belong to the text.
    ///
    /// - A number at the start of a paragraph is a verse number and sets the count.
    /// - Inside a paragraph, only the next number in the count is removed (16, then 17), so
    ///   "3 days and 40 nights" survives.
    /// - A paste that starts mid-verse has no count yet: a number is taken when the very next
    ///   number is one higher ("... broke them. 37 And ... 38 Those").
    /// - A paragraph-start number followed by a 2 is a chapter number standing in for verse 1,
    ///   as Bible Gateway shows it ("23 The LORD is my shepherd ... 2 He makes me").
    /// - A paragraph that restarts at 1, or at a chapter number, begins a new chapter.
    private static func stripBareVerseNumbers(_ lines: [String]) -> (lines: [String], verses: [Int], spansChapters: Bool) {
        struct Candidate { let line: Int; let match: Match; let value: Int; let atLineStart: Bool }
        let pattern = #"(?<![\w,:.’'])(\d{1,3})(?=\s*[A-Za-z“‘"(])"#
        var candidates: [Candidate] = []
        for (i, line) in lines.enumerated() {
            for m in allMatches(pattern, in: line) {
                guard let n = Int(m.groups[0]) else { continue }
                candidates.append(Candidate(line: i, match: m, value: n,
                                            atLineStart: m.range.lowerBound == line.startIndex))
            }
        }

        var picked: [Candidate] = []
        var verses: [Int] = []
        var expected: Int?
        var spansChapters = false
        for (i, c) in candidates.enumerated() {
            let next = i + 1 < candidates.count ? candidates[i + 1].value : nil
            if c.atLineStart {
                let isChapterNumber = c.value != 1 && next == 2 && c.value != expected
                let verse = isChapterNumber ? 1 : c.value
                if let e = expected, verse < e - 1 { spansChapters = true }
                picked.append(c); verses.append(verse); expected = verse + 1
            } else if c.value == expected || (expected == nil && next == c.value + 1) {
                picked.append(c); verses.append(c.value); expected = c.value + 1
            }
        }

        var result = lines
        for c in picked.reversed() { result[c.line].replaceSubrange(c.match.range, with: " ") }
        return (result, verses, spansChapters)
    }

    // MARK: - Footnote letters without brackets

    /// "servanta of God" -> "servant of God" when "servanta" is not a word but "servant" is.
    /// Bible sites mark footnotes with a superscript letter that loses its formatting on copy.
    static func unstickFootnoteLetters(_ text: String, isWord: SpellCheck) -> String {
        // A letter stuck straight after punctuation: "brothers,b when" -> "brothers, when".
        // Apostrophes are left out on purpose: "person’s", "Lord’s", "can’t" are real words.
        var result = replace(#"(?<=[,.;:!?”"])[a-z](?=\s|$)"#, in: text, with: "")
        for match in allMatches(#"\b([A-Za-z’']{3,})([a-z])\b"#, in: result).reversed() {
            let word = match.groups[0] + match.groups[1]
            let stem = match.groups[0]
            if !isWord(word), isWord(stem) { result.replaceSubrange(match.range, with: stem) }
        }
        return result
    }

    #if canImport(UIKit)
    static let defaultSpellCheck: SpellCheck? = { word in
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: (word as NSString).length)
        return checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0,
                                             wrap: false, language: "en_US").location == NSNotFound
    }
    #elseif canImport(AppKit)
    static let defaultSpellCheck: SpellCheck? = { word in
        var count = 0
        return NSSpellChecker.shared.checkSpelling(of: word, startingAt: 0, language: "en", wrap: false,
                                                   inSpellDocumentWithTag: 0, wordCount: &count).location == NSNotFound
    }
    #else
    static let defaultSpellCheck: SpellCheck? = nil
    #endif

    // MARK: - Whitespace and punctuation

    private static func tidy(_ text: String) -> String {
        var t = replace(#"\s+"#, in: text, with: " ")
        t = replace(#"\s+([,.;:!?”’)])"#, in: t, with: "$1")
        t = replace(#"([“‘(])\s+"#, in: t, with: "$1")
        return t.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Regex helpers

    private struct Match {
        let range: Range<String.Index>
        let groups: [String]
    }

    private static func allMatches(_ pattern: String, in text: String) -> [Match] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: ns).compactMap { result in
            guard let range = Range(result.range, in: text) else { return nil }
            let groups = (1..<max(result.numberOfRanges, 1)).map { i -> String in
                guard let r = Range(result.range(at: i), in: text) else { return "" }
                return String(text[r])
            }
            return Match(range: range, groups: groups)
        }
    }

    private static func firstMatch(_ pattern: String, in text: String) -> Match? {
        allMatches(pattern, in: text).first
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text),
                                              withTemplate: template)
    }
}
