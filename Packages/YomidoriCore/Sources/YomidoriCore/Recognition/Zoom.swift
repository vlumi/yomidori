import CoreGraphics

/// The still's scale and pan in its view; the pan is kept inside the slack the scale leaves.
public struct Zoom: Equatable, Sendable {
    public var scale: CGFloat
    public var offset: CGSize

    public static let range: ClosedRange<CGFloat> = 1...6

    public init(scale: CGFloat = 1, offset: CGSize = .zero) {
        self.scale = scale
        self.offset = offset
    }

    /// The image filling the view's width, its top at the top, where reading starts.
    public static func fillingWidth(of imageSize: CGSize, in bounds: CGSize) -> Zoom {
        let fitted = TextGeometry.fittedFrame(of: imageSize, in: bounds)
        guard fitted.width > 0 else { return Zoom() }
        let scale = min(max(bounds.width / fitted.width, range.lowerBound), range.upperBound)
        return Zoom(scale: scale, offset: CGSize(width: 0, height: bounds.height * (scale - 1) / 2))
    }

    public func stepped(by factor: CGFloat, in bounds: CGSize) -> Zoom {
        let scale = min(max(self.scale * factor, Zoom.range.lowerBound), Zoom.range.upperBound)
        let applied = scale / self.scale
        return Zoom(
            scale: scale,
            offset: CGSize(width: offset.width * applied, height: offset.height * applied)
        ).clamped(in: bounds)
    }

    public func clamped(in bounds: CGSize) -> Zoom {
        let slackX = bounds.width * (scale - 1) / 2
        let slackY = bounds.height * (scale - 1) / 2
        return Zoom(
            scale: scale,
            offset: CGSize(
                width: min(max(offset.width, -slackX), slackX),
                height: min(max(offset.height, -slackY), slackY)))
    }
}
