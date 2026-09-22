import Vision
import YomidoriCore

/// Vision, tried in order: the document request new in iOS 26, which returns lines with
/// boxes as structure; then the plain text request, which never read vertical Japanese and
/// is the floor.
enum TextRecognizer {
    static func recognize(_ still: Still) async throws -> [RecognizedLine] {
        let image = still.image
        let document = try await recognizeDocument(image)
        return document.isEmpty ? try await recognizeText(image) : document
    }

    private static func recognizeDocument(_ image: CGImage) async throws -> [RecognizedLine] {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "ja")]
        let observations = try await request.perform(on: image)
        return observations.flatMap { observation in
            observation.document.text.lines.map { line in
                RecognizedLine(
                    text: line.transcript, box: line.boundingRegion.boundingBox.cgRect,
                    confidence: 1)
            }
        }
    }

    private static func recognizeText(_ image: CGImage) async throws -> [RecognizedLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "ja")]
        let observations = try await request.perform(on: image)
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedLine(
                text: candidate.string, box: observation.boundingBox.cgRect,
                confidence: candidate.confidence)
        }
    }
}
