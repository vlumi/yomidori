import CoreGraphics

/// One line of text as the recognizer read it, and where it sits on the still.
/// The box is normalized to the image, 0...1 on both axes with y up, as Vision
/// reports it; `TextGeometry` is the one place that maps it to a view.
public struct RecognizedLine: Equatable, Sendable {
    public let text: String
    public let box: CGRect
    /// The recognizer's confidence in `text`, 0...1.
    public let confidence: Float

    public init(text: String, box: CGRect, confidence: Float) {
        self.text = text
        self.box = box
        self.confidence = confidence
    }
}
