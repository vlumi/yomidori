import VisionKit
import YomidoriCore

/// A still read by both recognizers at once, as child tasks: a cancel reaches both instead
/// of waiting for the first to finish. Vision's lines come with their boxes; Live Text's
/// analysis carries the transcript and, on iOS, its own selection on the picture, and is nil
/// where Live Text does not run.
enum PageRecognition {
    static func read(_ still: Still) async -> (lines: [RecognizedLine], analysis: ImageAnalysis?) {
        async let lines = (try? TextRecognizer.recognize(still)) ?? []
        async let analysis = LiveText.isSupported ? try? LiveText.analyze(still) : nil
        return await (lines, analysis)
    }
}
