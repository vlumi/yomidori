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
}
