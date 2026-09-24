/// One of the parts kanji are built from, as KRADFILE lists them, for finding a kanji by
/// the pieces the reader can see in it.
public struct KanjiPart: Hashable, Sendable, Identifiable {
    /// As KRADFILE writes it, which is what a query needs.
    public let component: String
    /// As the reader knows it: the radical itself where KRADFILE writes a kanji standing in.
    public let glyph: String
    public let strokes: Int?

    public var id: String { component }

    /// KRADFILE writes some radicals as a kanji containing them, 汁 for 氵; the reader looks
    /// for the radical, with its own stroke count.
    static let standIns: [String: (glyph: String, strokes: Int)] = [
        "化": ("亻", 2), "刈": ("刂", 2), "込": ("辶", 3), "忙": ("忄", 3), "扎": ("扌", 3),
        "汁": ("氵", 3), "犯": ("犭", 3), "艾": ("艹", 3), "尚": ("⺌", 3), "杰": ("灬", 4),
        "礼": ("礻", 4), "老": ("耂", 4), "初": ("衤", 5), "疔": ("疒", 5), "買": ("罒", 5),
    ]

    /// The parts that are no kanji of their own, and so have no stroke count in KANJIDIC.
    static let symbols: [String: Int] = ["｜": 1, "ノ": 1, "ハ": 2, "マ": 2, "ユ": 2, "ヨ": 3]

    public init(component: String, strokes: Int?) {
        self.component = component
        if let standIn = Self.standIns[component] {
            glyph = standIn.glyph
            self.strokes = standIn.strokes
        } else {
            glyph = component
            self.strokes = Self.symbols[component] ?? strokes
        }
    }

    public struct Group: Sendable {
        public let strokes: Int?
        public let parts: [KanjiPart]
    }

    /// The parts by stroke count, fewest first, those of unknown count last; within a count in
    /// the order given.
    public static func byStrokes(_ parts: [KanjiPart]) -> [Group] {
        let groups = Dictionary(grouping: parts, by: \.strokes)
        return groups.keys.sorted { ($0 ?? .max) < ($1 ?? .max) }.map {
            Group(strokes: $0, parts: groups[$0] ?? [])
        }
    }
}
