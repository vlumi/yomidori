import Foundation

/// Pages joined at the seam with no break, so a word cut by the page turn tokenizes whole.
public enum Spread {
    public static func join(_ transcripts: [String]) -> String {
        transcripts
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
            .joined()
    }

    public static func offset(ofPage index: Int, in transcripts: [String]) -> Int {
        transcripts.prefix(index)
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
            .reduce(0) { $0 + $1.count }
    }
}
