import Foundation

/// The old kanji forms prewar print uses (國, 學, 戰), and other variants, as the modern
/// forms the dictionary lists words under: a word the dictionary has no entry for as
/// written is looked up again in modern forms.
public enum OldKanji {
    private static let table: [Unicode.Scalar: Unicode.Scalar] = {
        let scalars = Array(pairs.unicodeScalars)
        var table: [Unicode.Scalar: Unicode.Scalar] = [:]
        for index in stride(from: 0, to: scalars.count - 1, by: 2) {
            table[scalars[index]] = scalars[index + 1]
        }
        return table
    }()

    /// The text with its old forms made modern (戰爭 → 戦争); nil where it has none.
    public static func modern(_ text: String) -> String? {
        var changed = false
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if let modern = table[scalar] {
                out.append(modern)
                changed = true
            } else {
                out.append(scalar)
            }
        }
        return changed ? String(out) : nil
    }
}
