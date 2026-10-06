import CoreGraphics

/// One character as a tile's recognizer saw it: its box in the page's normalized
/// coordinates (y up, as Vision gives them), and the centre of the tile that saw it. Where
/// tiles overlap a character is seen twice, and read alike or not; it belongs to the tile
/// whose centre is nearest, which sees it whole and in its context.
public struct TileGlyph: Equatable, Sendable {
    public let character: Character
    public let box: CGRect
    public let tile: CGPoint

    public init(character: Character, box: CGRect, tile: CGPoint) {
        self.character = character
        self.box = box
        self.tile = tile
    }
}

/// A dense page read twice: once whole, for its lines, and once in tiles, for its
/// characters. Vision works at a size of its own however large the frame, so on a full
/// page of small print the furigana melt into the kanji beside them and the kanji come
/// out wrong; a tile is the same page seen closer. The whole page's lines are the
/// skeleton; the tiles' characters are laid into them, each from the tile it belongs to, so
/// the seams echo nothing, and the furigana — small kana off a line's axis — dropped.
///
/// Sizes are in heights of the image: `aspect`, the image's width over its height, puts
/// widths and heights, each normalized to its own side, on one scale.
public enum TileStitch {
    /// The page's character size: the upper quartile of the characters' extent along their
    /// lines, a kanji filling its square and kana less of it. Across a line Vision's boxes
    /// are the line's own width, furigana and all, and say nothing of the character.
    public static func usualSize(of lines: [RecognizedLine], aspect: CGFloat = 1) -> CGFloat {
        let sizes = lines.flatMap { line in
            line.characterBoxes.map { extent($0, line.isVertical, aspect) }
        }.sorted()
        return sizes.isEmpty ? 0 : sizes[sizes.count * 3 / 4]
    }

    /// How far apart the characters stand along their lines: the median step between
    /// neighbours, which is the print's size whatever the boxes say.
    public static func characterPitch(of lines: [RecognizedLine], aspect: CGFloat = 1) -> CGFloat {
        var steps: [CGFloat] = []
        for line in lines where line.characterBoxes.count >= 2 {
            let positions = line.characterBoxes.map { position($0, line.isVertical, aspect) }
            for (first, second) in zip(positions, positions.dropFirst()) {
                steps.append(abs(second - first))
            }
        }
        steps.sort()
        return steps.isEmpty ? 0 : steps[steps.count / 2]
    }

    /// Without the lines that are furigana of their own: kana only, and well under the
    /// page's size across.
    public static func droppingRubyLines(
        _ lines: [RecognizedLine], usual: CGFloat, aspect: CGFloat = 1
    ) -> [RecognizedLine] {
        guard usual > 0 else { return lines }
        return lines.filter { line in
            !(across(line.box, line.isVertical, aspect) < usual * 0.75 && Kana.isKana(line.text))
        }
    }

    /// The skeleton's lines with the tiles' characters in them; a line no tile saw into keeps
    /// its own text.
    public static func stitch(
        _ skeleton: [RecognizedLine], with glyphs: [TileGlyph], aspect: CGFloat = 1
    ) -> [RecognizedLine] {
        let usual = usualSize(of: skeleton, aspect: aspect)
        guard usual > 0, !glyphs.isEmpty else { return skeleton }
        let kept = homed(glyphs, aspect: aspect)
        return skeleton.map { line in
            let vertical = line.isVertical
            let widened = line.box.insetBy(
                dx: vertical ? -line.box.width * 0.3 : 0, dy: vertical ? 0 : -line.box.height * 0.3)
            var inside = kept.filter { widened.contains(center(of: $0.box)) }
            // The line's axis runs through its full-size characters; furigana is small kana
            // off it, as `RecognizedLine.droppingRuby` has it.
            let big = inside.filter { extent($0.box, vertical, aspect) >= usual * 0.85 }
                .map { offAxis(center(of: $0.box), vertical, aspect) }.sorted()
            let axis =
                big.isEmpty ? offAxis(center(of: line.box), vertical, aspect) : big[big.count / 2]
            inside.removeAll { glyph in
                Kana.isKana(String(glyph.character))
                    && extent(glyph.box, vertical, aspect) < usual * 0.7
                    && abs(offAxis(center(of: glyph.box), vertical, aspect) - axis) > usual * 0.4
            }
            inside = inOrder(inside, vertical: vertical, usual: usual, aspect: aspect)
            guard !inside.isEmpty else { return line }
            return RecognizedLine(
                text: String(inside.map(\.character)), box: line.box, confidence: line.confidence,
                characterBoxes: inside.map(\.box))
        }
    }

    /// Each character from the tile whose centre is nearest to it, and from that tile only.
    private static func homed(_ glyphs: [TileGlyph], aspect: CGFloat) -> [TileGlyph] {
        let tiles = Set(glyphs.map { Tile(point: $0.tile) }).map(\.point)
        guard tiles.count > 1 else { return glyphs }
        return glyphs.filter { glyph in
            let point = center(of: glyph.box)
            let home = tiles.min { first, second in
                distance(point, first, aspect) < distance(point, second, aspect)
            }
            return home == glyph.tile
        }
    }

    private struct Tile: Hashable {
        let point: CGPoint
        func hash(into hasher: inout Hasher) {
            hasher.combine(point.x)
            hasher.combine(point.y)
        }
    }

    private static func distance(_ point: CGPoint, _ tile: CGPoint, _ aspect: CGFloat) -> CGFloat {
        let dx = (point.x - tile.x) * aspect
        let dy = point.y - tile.y
        return dx * dx + dy * dy
    }

    /// Along the line, in reading order — a column from its top, a row from its left. Two
    /// characters standing on one spot are one character the recognizer gave two boxes: the
    /// kanji stays over a kana, since furigana is kana and the line's own kanji are not.
    private static func inOrder(
        _ glyphs: [TileGlyph], vertical: Bool, usual: CGFloat, aspect: CGFloat
    ) -> [TileGlyph] {
        let sorted = glyphs.sorted { first, second in
            vertical ? first.box.midY > second.box.midY : first.box.midX < second.box.midX
        }
        var ordered: [TileGlyph] = []
        for glyph in sorted {
            if let last = ordered.last,
                abs(position(glyph.box, vertical, aspect) - position(last.box, vertical, aspect))
                    < usual * 0.5
            {
                if outranks(glyph, last) { ordered[ordered.count - 1] = glyph }
                continue
            }
            ordered.append(glyph)
        }
        return ordered
    }

    private static func outranks(_ glyph: TileGlyph, _ other: TileGlyph) -> Bool {
        !Kana.isKana(String(glyph.character)) && Kana.isKana(String(other.character))
    }

    private static func center(of box: CGRect) -> CGPoint { CGPoint(x: box.midX, y: box.midY) }
    /// A box's size across the line: a column's width.
    private static func across(_ box: CGRect, _ vertical: Bool, _ aspect: CGFloat) -> CGFloat {
        vertical ? box.width * aspect : box.height
    }
    /// A box's extent along the line: a column's character's height.
    private static func extent(_ box: CGRect, _ vertical: Bool, _ aspect: CGFloat) -> CGFloat {
        vertical ? box.height : box.width * aspect
    }
    /// A point's coordinate across the line.
    private static func offAxis(_ point: CGPoint, _ vertical: Bool, _ aspect: CGFloat) -> CGFloat {
        vertical ? point.x * aspect : point.y
    }
    /// A box's place along the line.
    private static func position(_ box: CGRect, _ vertical: Bool, _ aspect: CGFloat) -> CGFloat {
        vertical ? box.midY : box.midX * aspect
    }
}
