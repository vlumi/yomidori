import CoreGraphics

/// The box is normalized to the image with y up, as Vision reports it.
public struct RecognizedLine: Equatable, Sendable {
    public let text: String
    public let box: CGRect
    public let confidence: Float

    public init(text: String, box: CGRect, confidence: Float) {
        self.text = text
        self.box = box
        self.confidence = confidence
    }
}
