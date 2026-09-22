import Foundation

/// The words read off a cover, for the name and the note: Vision's lines tallest first, so
/// the title leads; Live Text's transcript fills in what Vision missed, vertical print among it.
public enum CoverLines {
    public static func merge(vision: [RecognizedLine], liveText transcript: String?) -> [String] {
        var found = vision.sorted { $0.box.height > $1.box.height }.map(\.text)
        for line in (transcript ?? "").split(whereSeparator: \.isNewline) {
            let text = line.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty, !found.contains(text) { found.append(text) }
        }
        return found
    }
}
