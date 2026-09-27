import Foundation

/// A typed meaning against the meanings that count: case, articles, "to", parentheticals
/// and punctuation set aside; a whole meaning, one that contains the answer as a whole
/// phrase, one typo away, or the same words in another form (cut for cutting, carries for
/// carry) all count.
public enum MeaningCheck {
    public static func matches(typed: String, glosses: [String], accepted: [String] = [])
        -> Bool
    {
        let answer = normalize(typed)
        guard !answer.isEmpty else { return false }
        let stemmed = stems(answer)
        return (glosses + accepted).contains { gloss in
            let candidate = normalize(gloss)
            guard !candidate.isEmpty else { return false }
            return candidate == answer || containsPhrase(candidate, answer)
                || (answer.count >= 4 && editDistance(candidate, answer) <= 1)
                || stems(candidate) == stemmed || containsPhrase(stems(candidate), stemmed)
        }
    }

    /// Each word cut to a rough stem: -ies to y, -ing, -ed, -es, -s and -ly off, a doubled
    /// last consonant undoubled (cutting to cut) and a final e dropped (make, making to mak).
    static func stems(_ text: String) -> String {
        text.split(separator: " ").map { stem(String($0)) }.joined(separator: " ")
    }

    private static func stem(_ word: String) -> String {
        var stem = word
        if stem.count > 4, stem.hasSuffix("ies") {
            stem = String(stem.dropLast(3)) + "y"
        } else {
            for suffix in ["ing", "ed", "es", "ly", "s"]
            where stem.count > suffix.count + 2 && stem.hasSuffix(suffix) && !stem.hasSuffix("ss") {
                stem = String(stem.dropLast(suffix.count))
                break
            }
        }
        let letters = Array(stem)
        if letters.count > 3, letters[letters.count - 1] == letters[letters.count - 2],
            !"aeiou".contains(letters[letters.count - 1])
        {
            stem = String(stem.dropLast())
        }
        if stem.count > 3, stem.hasSuffix("e") { stem = String(stem.dropLast()) }
        return stem
    }

    static func normalize(_ text: String) -> String {
        var stripped = text.lowercased()
        stripped = stripped.replacingOccurrences(
            of: "\\([^)]*\\)", with: "", options: .regularExpression)
        stripped = stripped.replacingOccurrences(
            of: "[^a-z0-9\\s'-]", with: " ", options: .regularExpression)
        let words = stripped.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let kept = words.enumerated().filter { index, word in
            !(index == 0 && ["to", "a", "an", "the"].contains(word))
        }.map(\.element)
        return kept.joined(separator: " ")
    }

    private static func containsPhrase(_ text: String, _ phrase: String) -> Bool {
        let words = text.split(separator: " ")
        let wanted = phrase.split(separator: " ")
        guard !wanted.isEmpty, words.count > wanted.count else { return false }
        return (0...(words.count - wanted.count)).contains { start in
            Array(words[start..<start + wanted.count]) == wanted
        }
    }

    /// Edits with adjacent transpositions counted as one, since a typo is usually one.
    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard abs(a.count - b.count) <= 1 else { return 2 }
        var rows = [Array(0...b.count)]
        for (i, ca) in a.enumerated() {
            var current = [i + 1]
            for (j, cb) in b.enumerated() {
                var cost = min(rows[i][j + 1] + 1, current[j] + 1, rows[i][j] + (ca == cb ? 0 : 1))
                if i > 0, j > 0, ca == b[j - 1], a[i - 1] == cb {
                    cost = min(cost, rows[i - 1][j - 1] + 1)
                }
                current.append(cost)
            }
            rows.append(current)
        }
        return rows[a.count][b.count]
    }
}
