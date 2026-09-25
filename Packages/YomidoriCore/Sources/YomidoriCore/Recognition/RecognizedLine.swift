import CoreGraphics

/// The box is normalized to the image with y up, as Vision reports it.
public struct RecognizedLine: Equatable, Sendable {
    public let text: String
    public let box: CGRect
    public let confidence: Float
    /// One box per character of `text`, normalized like `box`; empty where the recognizer
    /// gave none, and then a character is placed by its share of the line.
    public let characterBoxes: [CGRect]

    public init(text: String, box: CGRect, confidence: Float, characterBoxes: [CGRect] = []) {
        self.text = text
        self.box = box
        self.confidence = confidence
        self.characterBoxes = characterBoxes.count == text.count ? characterBoxes : []
    }

    /// Taller than wide: a vertical column, read top to bottom.
    public var isVertical: Bool { box.height > box.width }

    /// The box of the characters in `range`, their union; the line's own share of its box
    /// where there are no character boxes.
    public func box(ofCharacters range: Range<Int>) -> CGRect {
        let range = range.clamped(to: 0..<text.count)
        guard !range.isEmpty else { return .null }
        if !characterBoxes.isEmpty {
            return characterBoxes[range].reduce(CGRect.null) { $0.union($1) }
        }
        let count = CGFloat(max(text.count, 1))
        let start = CGFloat(range.lowerBound) / count
        let length = CGFloat(range.count) / count
        if isVertical {
            // y is up, and a column is read from its top.
            return CGRect(
                x: box.minX, y: box.maxY - (start + length) * box.height, width: box.width,
                height: length * box.height)
        }
        return CGRect(
            x: box.minX + start * box.width, y: box.minY, width: length * box.width,
            height: box.height)
    }

    /// The line without its furigana. Vision reads the small kana beside a column (or above a
    /// row) into the line, 僅わずか for 僅: a kana well under the line's own characters in
    /// size and off its axis is taken for furigana and dropped. Small kana of the text itself
    /// (っ, ゃ) sit near the axis and stay. Without character boxes there is nothing to go by.
    public func droppingRuby() -> RecognizedLine {
        guard characterBoxes.count >= 3 else { return self }
        let vertical = isVertical
        // Across the line: a column's characters are as wide as the column, a row's as tall.
        let size = { (box: CGRect) in vertical ? box.width : box.height }
        let center = { (box: CGRect) in vertical ? box.midX : box.midY }
        // The line's own characters are the larger ones, however much furigana a short
        // line has; its axis runs through them.
        let sizes = characterBoxes.map(size).sorted()
        let usual = sizes[sizes.count * 3 / 4]
        guard usual > 0 else { return self }
        let axis = Self.median(characterBoxes.filter { size($0) >= usual * 0.85 }.map(center))
        var kept = ""
        var keptBoxes: [CGRect] = []
        for (character, box) in zip(text, characterBoxes) {
            let isRuby =
                Kana.isKana(String(character)) && size(box) < usual * 0.7
                && abs(center(box) - axis) > usual * 0.4
            if !isRuby {
                kept.append(character)
                keptBoxes.append(box)
            }
        }
        guard kept.count < text.count else { return self }
        return RecognizedLine(
            text: kept, box: box, confidence: confidence, characterBoxes: keptBoxes)
    }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    }
}
