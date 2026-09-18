import Foundation

/// Several pages read as one text. The pages' transcripts are joined at the seam
/// with no break at all, so a word cut by the page turn (樹 at the foot of one page,
/// 皮 at the head of the next) tokenizes whole and a sentence runs on; inside a page
/// the line breaks stay as they were.
public enum Spread {
    public static func join(_ transcripts: [String]) -> String {
        transcripts
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
            .joined()
    }

    /// Where page `index`'s text starts in the joined text, in characters, so a
    /// position in one page's transcript maps into the whole.
    public static func offset(ofPage index: Int, in transcripts: [String]) -> Int {
        transcripts.prefix(index)
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
            .reduce(0) { $0 + $1.count }
    }
}
