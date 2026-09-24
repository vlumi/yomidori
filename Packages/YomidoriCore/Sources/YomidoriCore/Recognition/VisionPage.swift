import CoreGraphics

/// A page as Vision read it: its lines in reading order as one text, and the way from a tap
/// to a character of it.
public struct VisionPage: Sendable {
    public let lines: [RecognizedLine]
    public let transcript: String
    /// Where each line starts in `transcript`, in characters.
    public let starts: [Int]

    public init(lines: [RecognizedLine]) {
        let kept = lines.filter { !$0.text.isEmpty }
        self.lines = kept
        var starts: [Int] = []
        var offset = 0
        for line in kept {
            starts.append(offset)
            offset += line.text.count + 1
        }
        self.starts = starts
        transcript = kept.map(\.text).joined(separator: "\n")
    }

    /// The line under a tap in view space and the character on it: the character whose box
    /// holds the tap, else the nearest along the line.
    public func character(at point: CGPoint, in frame: CGRect) -> (line: Int, character: Int)? {
        guard let line = TextGeometry.lineIndex(at: point, in: frame, lines: lines) else {
            return nil
        }
        let recognized = lines[line]
        let count = recognized.text.count
        guard count > 0 else { return nil }
        let centers = (0..<count).map { index -> CGPoint in
            let rect = TextGeometry.viewRect(
                for: recognized.box(ofCharacters: index..<index + 1), in: frame)
            return CGPoint(x: rect.midX, y: rect.midY)
        }
        let nearest = centers.indices.min { first, second in
            distance(centers[first], point, vertical: recognized.isVertical)
                < distance(centers[second], point, vertical: recognized.isVertical)
        }
        return nearest.map { (line, $0) }
    }

    /// Along the line counts; across it hardly, since a tap anywhere across a column means it.
    private func distance(_ center: CGPoint, _ point: CGPoint, vertical: Bool) -> CGFloat {
        let along = vertical ? center.y - point.y : center.x - point.x
        let across = vertical ? center.x - point.x : center.y - point.y
        return along * along + 0.01 * across * across
    }
}
