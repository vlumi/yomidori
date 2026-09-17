import Vision
import YomidoriCore

/// Vision's text recognition for Japanese, run once over a still, on the device.
enum TextRecognizer {
    static func recognize(_ still: Still) async throws -> [RecognizedLine] {
        let image = still.image
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.revision = VNRecognizeTextRequestRevision3
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP"]
            try VNImageRequestHandler(cgImage: image).perform([request])
            return (request.results ?? []).compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return RecognizedLine(
                    text: candidate.string, box: observation.boundingBox,
                    confidence: candidate.confidence)
            }
        }.value
    }
}
