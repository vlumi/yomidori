import Vision
import YomidoriCore

/// Vision's document request: lines with their boxes, vertical columns included.
enum TextRecognizer {
    static func recognize(_ still: Still) async throws -> [RecognizedLine] {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "ja")]
        let observations = try await request.perform(on: still.image)
        return observations.flatMap { observation in
            observation.document.text.lines.map { line in
                RecognizedLine(
                    text: line.transcript, box: line.boundingRegion.boundingBox.cgRect,
                    confidence: line.confidence)
            }
        }
    }
}
