import Foundation

/// One stroke as KanjiVG draws it: SVG path data in a 109 × 109 box, and where its number
/// is printed.
public struct KanjiStroke: Hashable, Sendable {
    public static let boxSide: CGFloat = 109
    public let path: String
    public let label: CGPoint?

    public init(path: String, label: CGPoint?) {
        self.path = path
        self.label = label
    }
}

/// One kanji as KANJIDIC2 has it, with KRADFILE's components and KanjiVG's strokes. Kun
/// readings keep KANJIDIC's marks: a dot before the okurigana (う.える), a hyphen where the
/// kanji is a prefix or suffix.
public struct KanjiEntry: Hashable, Sendable {
    public let literal: String
    public let onReadings: [String]
    public let kunReadings: [String]
    public let nanori: [String]
    public let meanings: [String]
    public let strokes: Int?
    public let grade: Int?
    public let jlpt: Int?
    public let frequency: Int?
    public let components: [String]
    public let strokeOrder: [KanjiStroke]

    public init(
        literal: String, onReadings: [String], kunReadings: [String], nanori: [String],
        meanings: [String], strokes: Int?, grade: Int?, jlpt: Int?, frequency: Int?,
        components: [String], strokeOrder: [KanjiStroke] = []
    ) {
        self.literal = literal
        self.onReadings = onReadings
        self.kunReadings = kunReadings
        self.nanori = nanori
        self.meanings = meanings
        self.strokes = strokes
        self.grade = grade
        self.jlpt = jlpt
        self.frequency = frequency
        self.components = components
        self.strokeOrder = strokeOrder
    }

    /// The kanji in a text, each once, in order.
    public static func literals(in text: String) -> [String] {
        var seen: Set<Character> = []
        return text.filter { character in
            guard let scalar = character.unicodeScalars.first, isKanji(scalar) else { return false }
            return seen.insert(character).inserted
        }.map(String.init)
    }

    public static func isKanji(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
            || (0xF900...0xFAFF).contains(scalar.value) || scalar.value == 0x3005
    }
}
