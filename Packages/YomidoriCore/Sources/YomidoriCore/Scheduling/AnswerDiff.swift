import Foundation

/// What was typed held against the answer, character by character, so a slip shows as a
/// slip: the characters that match, the ones typed that should not have been, and the ones
/// of the answer that were not typed. Aligned by the longest common subsequence, so one
/// wrong kana in the middle marks one kana, not everything after it.
public enum AnswerDiff {
    public enum Part: Equatable, Sendable {
        case same(String)
        /// In what was typed, not in the answer.
        case extra(String)
        /// In the answer, not in what was typed.
        case missing(String)
    }

    /// The alignment, read left to right. Both sides are normalized as the reading check
    /// normalizes them (hiragana, no spaces), so a katakana answer is no slip.
    public static func of(typed: String, answer: String) -> [Part] {
        let a = Array(ReadingCheck.normalize(typed))
        let b = Array(ReadingCheck.normalize(answer))
        // The subsequence table, then a walk back from the far corner.
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] =
                    a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var parts: [Part] = []
        var i = 0
        var j = 0
        func add(_ part: Part) {
            switch (parts.last, part) {
            case (.same(let s), .same(let t)): parts[parts.count - 1] = .same(s + t)
            case (.extra(let s), .extra(let t)): parts[parts.count - 1] = .extra(s + t)
            case (.missing(let s), .missing(let t)): parts[parts.count - 1] = .missing(s + t)
            default: parts.append(part)
            }
        }
        while i < a.count, j < b.count {
            if a[i] == b[j] {
                add(.same(String(a[i])))
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                add(.extra(String(a[i])))
                i += 1
            } else {
                add(.missing(String(b[j])))
                j += 1
            }
        }
        while i < a.count {
            add(.extra(String(a[i])))
            i += 1
        }
        while j < b.count {
            add(.missing(String(b[j])))
            j += 1
        }
        return parts
    }
}
