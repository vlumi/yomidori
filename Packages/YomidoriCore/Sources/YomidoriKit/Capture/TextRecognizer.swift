import Vision
import YomidoriCore

/// Vision's document request: lines with their boxes, vertical columns included, and each
/// character's box, for a tap to land on a character.
enum TextRecognizer {
    static func recognize(_ still: Still) async throws -> [RecognizedLine] {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "ja")]
        let observations = try await request.perform(on: still.image)
        return observations.flatMap { observation in
            observation.document.text.lines.map(line)
        }
    }

    private static func line(_ line: RecognizedTextObservation) -> RecognizedLine {
        guard let candidate = line.topCandidates(1).first else {
            return RecognizedLine(
                text: line.transcript, box: line.boundingRegion.boundingBox.cgRect,
                confidence: line.confidence)
        }
        let text = candidate.string
        var boxes: [CGRect] = []
        for index in text.indices {
            guard let box = candidate.boundingBox(for: index..<text.index(after: index)) else {
                boxes = []
                break
            }
            boxes.append(box.boundingBox.cgRect)
        }
        return RecognizedLine(
            text: text, box: line.boundingRegion.boundingBox.cgRect, confidence: line.confidence,
            characterBoxes: boxes)
    }
}
