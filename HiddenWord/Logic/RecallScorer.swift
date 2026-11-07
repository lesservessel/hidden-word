import Foundation

/// Scores a typed recall attempt against the verse text.
///
/// Both sides are lowercased and stripped of punctuation, then aligned word by word
/// with a longest-common-subsequence pass. Words count as matching when they are equal
/// or differ by a small typo (edit distance 1 for words of 4+ letters, 2 for 8+).
enum RecallScorer {
    struct Result {
        /// 0...1, matched words divided by the longer of target and attempt.
        let score: Double
        /// Indices of `WordToken`s in the target that were recalled.
        let recalledTokenIDs: Set<Int>
        let matchedWords: Int
        let targetWords: Int

        var percent: Int { Int((score * 100).rounded()) }
    }

    static func score(attempt: String, target: String) -> Result {
        let tokens = WordToken.tokenize(target)

        // Each normalized target word remembers which token it came from.
        var targetWords: [String] = []
        var owner: [Int] = []
        for token in tokens {
            for word in normalize(token.raw) {
                targetWords.append(word)
                owner.append(token.id)
            }
        }
        let attemptWords = normalize(attempt)

        let n = targetWords.count
        let m = attemptWords.count
        guard n > 0 else {
            return Result(score: m == 0 ? 1 : 0, recalledTokenIDs: Set(tokens.map(\.id)), matchedWords: 0, targetWords: 0)
        }

        // LCS table.
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    if wordsMatch(targetWords[i], attemptWords[j]) {
                        table[i][j] = table[i + 1][j + 1] + 1
                    } else {
                        table[i][j] = max(table[i + 1][j], table[i][j + 1])
                    }
                }
            }
        }

        // Walk the table to find which target words were matched.
        var matchedTarget = Set<Int>()
        var i = 0
        var j = 0
        while i < n && j < m {
            if wordsMatch(targetWords[i], attemptWords[j]) && table[i][j] == table[i + 1][j + 1] + 1 {
                matchedTarget.insert(i)
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }

        // A token is recalled when all of its words matched; punctuation-only tokens always are.
        var missedTokens = Set<Int>()
        for index in 0..<n where !matchedTarget.contains(index) {
            missedTokens.insert(owner[index])
        }
        let recalled = Set(tokens.map(\.id)).subtracting(missedTokens)

        let matched = matchedTarget.count
        let score = Double(matched) / Double(max(n, m))
        return Result(score: score, recalledTokenIDs: recalled, matchedWords: matched, targetWords: n)
    }

    /// Lowercase, fold accents and curly quotes, and split on anything that is not a letter or digit.
    static func normalize(_ text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        var words: [String] = []
        var currentWord = ""
        for character in folded {
            if character.isLetter || character.isNumber {
                currentWord.append(character)
            } else if !currentWord.isEmpty {
                words.append(currentWord)
                currentWord = ""
            }
        }
        if !currentWord.isEmpty { words.append(currentWord) }
        return words
    }

    static func wordsMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let shorter = min(a.count, b.count)
        let allowed: Int
        if shorter >= 8 {
            allowed = 2
        } else if shorter >= 4 {
            allowed = 1
        } else {
            return false
        }
        if abs(a.count - b.count) > allowed { return false }
        return editDistance(a, b) <= allowed
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let x = Array(a)
        let y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previous = Array(0...y.count)
        var row = Array(repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            row[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                row[j] = min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = row
        }
        return previous[y.count]
    }
}
