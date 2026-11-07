import Foundation

/// A whitespace-separated word of a verse, split into leading punctuation,
/// the word itself, and trailing punctuation.
struct WordToken: Identifiable, Hashable {
    let id: Int
    let raw: String
    let leading: String
    let core: String
    let trailing: String

    /// False for tokens that are only punctuation (e.g. a lone dash).
    var hasLetters: Bool { !core.isEmpty }

    /// "weakness.”" -> "w.”"
    var firstLetterHint: String {
        guard let first = core.first else { return raw }
        return leading + String(first) + trailing
    }

    /// "weakness.”" -> "________.”"
    var blanked: String {
        guard hasLetters else { return raw }
        return leading + String(repeating: "_", count: max(core.count, 2)) + trailing
    }

    static func tokenize(_ text: String) -> [WordToken] {
        text.split(whereSeparator: { $0.isWhitespace })
            .enumerated()
            .map { index, piece in WordToken(id: index, raw: String(piece)) }
    }

    init(id: Int, raw: String) {
        self.id = id
        self.raw = raw
        let chars = Array(raw)
        let isWordChar: (Character) -> Bool = { $0.isLetter || $0.isNumber }
        if let first = chars.firstIndex(where: isWordChar),
           let last = chars.lastIndex(where: isWordChar) {
            leading = String(chars[..<first])
            core = String(chars[first...last])
            trailing = String(chars[(last + 1)...])
        } else {
            leading = ""
            core = ""
            trailing = raw
        }
    }
}
