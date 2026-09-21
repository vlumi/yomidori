import CoreGraphics
import CoreML
import Foundation

/// manga-ocr as Core ML, converted by `Scripts/data/build-mangaocr.py`; reads one line
/// or bubble at a time, vertical included.
public final class MangaOCR {
    public static let bundled: MangaOCR? = {
        guard
            let encoder = Bundle.main.url(
                forResource: "MangaOCREncoder", withExtension: "mlmodelc"),
            let decoder = Bundle.main.url(
                forResource: "MangaOCRDecoder", withExtension: "mlmodelc"),
            let vocabulary = Bundle.main.url(forResource: "manga-ocr-vocab", withExtension: "txt")
        else { return nil }
        return try? MangaOCR(encoder: encoder, decoder: decoder, vocabulary: vocabulary)
    }()

    static let side = 224
    static let maxLength = 48
    static let start: Int32 = 2
    static let end: Int32 = 3

    private let encoder: MLModel
    private let decoder: MLModel
    private let vocabulary: [String]
    private let special: Set<String> = ["[CLS]", "[SEP]", "[PAD]", "[UNK]"]

    public init(encoder: URL, decoder: URL, vocabulary: URL) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        self.encoder = try MLModel(contentsOf: encoder, configuration: configuration)
        self.decoder = try MLModel(contentsOf: decoder, configuration: configuration)
        self.vocabulary = try String(contentsOf: vocabulary, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    public func read(_ image: CGImage) throws -> String {
        let pixels = try Self.pixels(of: image)
        let memory = try encoder.prediction(
            from: MLDictionaryFeatureProvider(dictionary: ["pixels": pixels])
        )
        .featureValue(for: "memory")!.multiArrayValue!
        let ids = try MLMultiArray(shape: [1, NSNumber(value: Self.maxLength)], dataType: .int32)
        let mask = try MLMultiArray(
            shape: [1, NSNumber(value: Self.maxLength)], dataType: .float32)
        for i in 0..<Self.maxLength {
            ids[i] = 0
            mask[i] = 0
        }
        ids[0] = NSNumber(value: Self.start)
        mask[0] = 1
        var tokens: [Int] = []
        for step in 1..<Self.maxLength {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "ids": ids, "mask": mask, "memory": memory,
            ])
            let logits = try decoder.prediction(from: input).featureValue(for: "logits")!
                .multiArrayValue!
            let next = Self.argmax(logits, row: step - 1)
            if next == Int(Self.end) { break }
            tokens.append(next)
            ids[step] = NSNumber(value: Int32(next))
            mask[step] = 1
        }
        return tokens.compactMap { vocabulary.indices.contains($0) ? vocabulary[$0] : nil }
            .filter { !special.contains($0) }
            .map { $0.replacingOccurrences(of: "##", with: "") }
            .joined()
    }

    /// Grey, 224 × 224, scaled to −1…1, the one channel repeated three times.
    static func pixels(of image: CGImage) throws -> MLMultiArray {
        guard
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
            let grey = { () -> UnsafeMutablePointer<UInt8>? in
                context.interpolationQuality = .high
                context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
                return context.data?.assumingMemoryBound(to: UInt8.self)
            }()
        else { throw CocoaError(.fileReadCorruptFile) }
        let array = try MLMultiArray(
            shape: [1, 3, NSNumber(value: side), NSNumber(value: side)], dataType: .float32)
        let out = array.dataPointer.assumingMemoryBound(to: Float32.self)
        let plane = side * side
        /// Bitmap memory runs top-down, as the model reads it; no flip.
        for y in 0..<side {
            for x in 0..<side {
                let value = (Float32(grey[y * side + x]) / 255 - 0.5) / 0.5
                let index = y * side + x
                out[index] = value
                out[plane + index] = value
                out[2 * plane + index] = value
            }
        }
        return array
    }

    private static func argmax(_ logits: MLMultiArray, row: Int) -> Int {
        let vocabulary = logits.shape[2].intValue
        let base = row * vocabulary
        var best = 0
        var bestValue = -Float.infinity
        switch logits.dataType {
        case .float16:
            let pointer = logits.dataPointer.assumingMemoryBound(to: Float16.self)
            for i in 0..<vocabulary where Float(pointer[base + i]) > bestValue {
                bestValue = Float(pointer[base + i])
                best = i
            }
        default:
            let pointer = logits.dataPointer.assumingMemoryBound(to: Float32.self)
            for i in 0..<vocabulary where pointer[base + i] > bestValue {
                bestValue = pointer[base + i]
                best = i
            }
        }
        return best
    }
}
