import CoreGraphics

/// Two pages laid out as one sheet, each still its own photo: side by side at one height, the
/// next page on the left as in a book of vertical text (or on the right), or one under the
/// other at one width, as horizontal text runs on.
public enum SpreadLayout {
    public enum Side: String, Codable, Sendable, CaseIterable {
        case left
        case right
        case below
    }

    /// Where the next page goes for text read this way: left of a page of columns, under a
    /// page of rows.
    public static func side(forVertical vertical: Bool) -> Side {
        vertical ? .left : .below
    }

    /// Whether a page is mostly columns, by the characters in them.
    public static func isVertical(_ lines: [RecognizedLine]) -> Bool {
        let vertical = lines.filter(\.isVertical).map(\.text.count).reduce(0, +)
        let all = lines.map(\.text.count).reduce(0, +)
        return all > 0 && vertical * 2 > all
    }

    /// Each page's frame in a sheet of the returned size, in reading order: the first page's
    /// frame first. Side by side, every page is scaled to the tallest's height; one under
    /// another, to the widest's width.
    public static func arrange(_ sizes: [CGSize], nextOn side: Side) -> (
        size: CGSize, frames: [CGRect]
    ) {
        let pages = sizes.filter { $0.width > 0 && $0.height > 0 }
        guard pages.count == sizes.count, !pages.isEmpty else { return (.zero, []) }
        switch side {
        case .below:
            let width = pages.map(\.width).max() ?? 0
            var y: CGFloat = 0
            let frames = pages.map { size -> CGRect in
                let height = size.height * width / size.width
                defer { y += height }
                return CGRect(x: 0, y: y, width: width, height: height)
            }
            return (CGSize(width: width, height: y), frames)
        case .left, .right:
            let height = pages.map(\.height).max() ?? 0
            let widths = pages.map { $0.width * height / $0.height }
            let total = widths.reduce(0, +)
            var x: CGFloat = side == .right ? 0 : total
            let frames = widths.map { width -> CGRect in
                if side == .left { x -= width }
                defer { if side == .right { x += width } }
                return CGRect(x: x, y: 0, width: width, height: height)
            }
            return (CGSize(width: total, height: height), frames)
        }
    }

    /// The frames of `arrange` fitted into a view of `bounds`, as the sheet is shown unzoomed.
    public static func fitted(_ sizes: [CGSize], nextOn side: Side, in bounds: CGSize)
        -> [CGRect]
    {
        let (size, frames) = arrange(sizes, nextOn: side)
        let sheet = TextGeometry.fittedFrame(of: size, in: bounds)
        guard size.width > 0 else { return [] }
        let scale = sheet.width / size.width
        return frames.map { frame in
            CGRect(
                x: sheet.minX + frame.minX * scale, y: sheet.minY + frame.minY * scale,
                width: frame.width * scale, height: frame.height * scale)
        }
    }

    /// The page under a point, by its frame; the nearest if the point is in none.
    public static func page(at point: CGPoint, in frames: [CGRect]) -> Int? {
        if let hit = frames.firstIndex(where: { $0.contains(point) }) { return hit }
        return frames.indices.min { first, second in
            distance(point, frames[first]) < distance(point, frames[second])
        }
    }

    private static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
