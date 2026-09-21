import CoreGraphics

/// Vision's boxes are normalized to the image with y up; the still is drawn aspect-fitted
/// in a view with y down.
public enum TextGeometry {
    public static func fittedFrame(of imageSize: CGSize, in bounds: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0
        else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height)
    }

    public static func viewRect(for box: CGRect, in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + box.minX * frame.width,
            y: frame.minY + (1 - box.maxY) * frame.height,
            width: box.width * frame.width,
            height: box.height * frame.height)
    }

    /// Where boxes overlap the smallest wins, so a short line inside a long one stays tappable.
    public static func lineIndex(at point: CGPoint, in frame: CGRect, lines: [RecognizedLine])
        -> Int?
    {
        lines.indices
            .filter { viewRect(for: lines[$0].box, in: frame).contains(point) }
            .min { area(lines[$0].box) < area(lines[$1].box) }
    }

    /// Image pixels, y down.
    public static func imagePoint(at point: CGPoint, in frame: CGRect, imageSize: CGSize)
        -> CGPoint?
    {
        guard frame.width > 0, frame.height > 0, frame.contains(point) else { return nil }
        return CGPoint(
            x: (point.x - frame.minX) / frame.width * imageSize.width,
            y: (point.y - frame.minY) / frame.height * imageSize.height)
    }

    /// Slid in at the edges, shrunk only where the image itself is smaller.
    public static func cropRect(around point: CGPoint, side: CGFloat, in imageSize: CGSize)
        -> CGRect
    {
        let width = min(side, imageSize.width)
        let height = min(side, imageSize.height)
        return CGRect(
            x: min(max(point.x - width / 2, 0), imageSize.width - width),
            y: min(max(point.y - height / 2, 0), imageSize.height - height),
            width: width, height: height)
    }

    public static func normalizedBox(for rect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: rect.minX / imageSize.width,
            y: 1 - rect.maxY / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height)
    }

    public static func imageRect(for box: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: box.minX * imageSize.width,
            y: (1 - box.maxY) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height)
    }

    public static func padded(_ rect: CGRect, by margin: CGFloat, in imageSize: CGSize) -> CGRect {
        rect.insetBy(dx: -margin, dy: -margin)
            .intersection(CGRect(origin: .zero, size: imageSize))
    }

    /// Along the line's long side, the whole of its short side, kept inside the line.
    public static func window(in line: CGRect, around point: CGPoint, characters: CGFloat) -> CGRect
    {
        if line.width >= line.height {
            let width = min(line.width, characters * line.height)
            let x = min(max(point.x - width / 2, line.minX), line.maxX - width)
            return CGRect(x: x, y: line.minY, width: width, height: line.height)
        }
        let height = min(line.height, characters * line.width)
        let y = min(max(point.y - height / 2, line.minY), line.maxY - height)
        return CGRect(x: line.minX, y: y, width: line.width, height: height)
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }
}
