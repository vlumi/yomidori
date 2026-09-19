import CoreGraphics

/// What a tap on the still gives the close-up readers: the crop the page readers get,
/// the whole line under the tap padded by its thickness, and the window the line
/// reader gets, about eight characters of that line around the tap. Where no line
/// was recognized (a vertical page), a square around the tap and a narrow column of
/// it stand in.
public struct CloseUpGeometry: Equatable {
    public let crop: CGRect
    public let window: CGRect

    public static let windowCharacters: CGFloat = 8

    public init?(tap point: CGPoint, in frame: CGRect, lines: [RecognizedLine], imageSize: CGSize) {
        guard let pixel = TextGeometry.imagePoint(at: point, in: frame, imageSize: imageSize) else {
            return nil
        }
        if let index = TextGeometry.lineIndex(at: point, in: frame, lines: lines) {
            let line = TextGeometry.imageRect(for: lines[index].box, imageSize: imageSize)
            crop = TextGeometry.padded(line, by: min(line.width, line.height) * 0.8, in: imageSize)
            window = TextGeometry.padded(
                TextGeometry.window(in: line, around: pixel, characters: Self.windowCharacters),
                by: line.height * 0.5, in: imageSize)
        } else {
            let side = max(imageSize.width, imageSize.height) / 3
            crop = TextGeometry.cropRect(around: pixel, side: side, in: imageSize)
            window = crop.intersection(
                CGRect(x: pixel.x - side / 8, y: 0, width: side / 4, height: imageSize.height))
        }
    }
}
