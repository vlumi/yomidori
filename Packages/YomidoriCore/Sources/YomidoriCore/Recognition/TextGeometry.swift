import CoreGraphics

/// The seam between the recognizer's coordinates and the screen. Vision reports
/// boxes normalized to the image with y up; the still is drawn aspect-fitted into
/// a view with y down. Everything that maps a tap to text goes through here.
public enum TextGeometry {
    /// Where an image of `imageSize` lands when aspect-fitted and centered in a
    /// view of `bounds`. Zero when either size is empty.
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

    /// A normalized, y-up box as a rect in the view the image is drawn in.
    public static func viewRect(for box: CGRect, in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + box.minX * frame.width,
            y: frame.minY + (1 - box.maxY) * frame.height,
            width: box.width * frame.width,
            height: box.height * frame.height)
    }

    /// The line under a point in view space, or nil outside every line. Where boxes
    /// overlap the smallest wins, so a short line inside a long one stays tappable.
    public static func lineIndex(at point: CGPoint, in frame: CGRect, lines: [RecognizedLine])
        -> Int?
    {
        lines.indices
            .filter { viewRect(for: lines[$0].box, in: frame).contains(point) }
            .min { area(lines[$0].box) < area(lines[$1].box) }
    }

    /// The image pixel under a point in the view, y down as `CGImage` counts rows.
    /// Nil outside the image's frame.
    public static func imagePoint(at point: CGPoint, in frame: CGRect, imageSize: CGSize)
        -> CGPoint?
    {
        guard frame.width > 0, frame.height > 0, frame.contains(point) else { return nil }
        return CGPoint(
            x: (point.x - frame.minX) / frame.width * imageSize.width,
            y: (point.y - frame.minY) / frame.height * imageSize.height)
    }

    /// A square of `side` pixels around a point, kept inside the image: slid in at
    /// the edges, shrunk only where the image itself is smaller.
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

    /// A rect in image pixels (y down) as the normalized y-up box the recognizer
    /// uses, so `viewRect(for:in:)` can draw it too.
    public static func normalizedBox(for rect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: rect.minX / imageSize.width,
            y: 1 - rect.maxY / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height)
    }

    /// The reverse of `normalizedBox(for:imageSize:)`: a recognizer's box as image pixels, y down.
    public static func imageRect(for box: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: box.minX * imageSize.width,
            y: (1 - box.maxY) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height)
    }

    /// The rect grown by `margin` on every side and kept inside the image, so a line
    /// is read whole, with the paper around it, and never a half-glyph at the edge.
    public static func padded(_ rect: CGRect, by margin: CGFloat, in imageSize: CGSize) -> CGRect {
        rect.insetBy(dx: -margin, dy: -margin)
            .intersection(CGRect(origin: .zero, size: imageSize))
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }
}
