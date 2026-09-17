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

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }
}
