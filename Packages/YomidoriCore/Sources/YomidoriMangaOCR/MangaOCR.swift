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
        guard
            let memory = try encoder.prediction(
                from: MLDictionaryFeatureProvider(dictionary: ["pixels": pixels])
            )
            .featureValue(for: "memory")?.multiArrayValue
        else { throw Self.unexpectedModel }
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
            guard
                let logits = try decoder.prediction(from: input).featureValue(for: "logits")?
                    .multiArrayValue,
                let next = Self.argmax(logits, row: step - 1)
            else { throw Self.unexpectedModel }
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

    /// Gray, 224 × 224, scaled to −1…1, the one channel repeated three times.
    static func pixels(of image: CGImage) throws -> MLMultiArray {
        guard
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
            let gray = { () -> UnsafeMutablePointer<UInt8>? in
                context.interpolationQuality = .high
                context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
                return context.data?.assumingMemoryBound(to: UInt8.self)
            }()
        else { throw CocoaError(.fileReadCorruptFile) }
        let array = try MLMultiArray(
            shape: [1, 3, NSNumber(value: side), NSNumber(value: side)], dataType: .float32)
        let out = array.dataPointer.assumingMemoryBound(to: Float32.self)
        let plane = side * side
        // Bitmap memory runs top-down, as the model reads it; no flip.
        for y in 0..<side {
            for x in 0..<side {
                let value = (Float32(gray[y * side + x]) / 255 - 0.5) / 0.5
                let index = y * side + x
                out[index] = value
                out[plane + index] = value
                out[2 * plane + index] = value
            }
        }
        return array
    }

    /// A model whose outputs aren't the ones this code was written for.
    static let unexpectedModel = CocoaError(.featureUnsupported)

    /// An IEEE half float's bits as a Float, for a CPU without the type.
    static func widened(_ bits: UInt16) -> Float {
        let sign = UInt32(bits >> 15) << 31
        let exponent = Int((bits >> 10) & 0x1F)
        let fraction = UInt32(bits & 0x3FF)
        let widenedBits: UInt32
        switch exponent {
        case 0:
            guard fraction != 0 else { return Float(bitPattern: sign) }
            // Subnormal: normalized by hand.
            var mantissa = fraction
            var shift: UInt32 = 0
            while mantissa & 0x400 == 0 {
                mantissa <<= 1
                shift += 1
            }
            widenedBits = sign | (UInt32(113 - shift) << 23) | ((mantissa & 0x3FF) << 13)
        case 0x1F:
            widenedBits = sign | 0x7F80_0000 | (fraction << 13)
        default:
            widenedBits = sign | (UInt32(exponent + 112) << 23) | (fraction << 13)
        }
        return Float(bitPattern: widenedBits)
    }

    /// The likeliest token at `row` of logits shaped [1, rows, vocabulary], following the
    /// array's strides; nil for any other shape.
    private static func argmax(_ logits: MLMultiArray, row: Int) -> Int? {
        guard logits.shape.count == 3, row < logits.shape[1].intValue else { return nil }
        let vocabulary = logits.shape[2].intValue
        let base = row * logits.strides[1].intValue
        let step = logits.strides[2].intValue
        var best = 0
        var bestValue = -Float.infinity
        switch logits.dataType {
        case .float16:
            // Read as the half floats they are where the CPU has them (every arm64 chip);
            // an Intel Mac has no Float16, and there the value is widened by hand.
            #if arch(arm64)
            let pointer = logits.dataPointer.assumingMemoryBound(to: Float16.self)
            for i in 0..<vocabulary where Float(pointer[base + i * step]) > bestValue {
                bestValue = Float(pointer[base + i * step])
                best = i
            }
            #else
            let pointer = logits.dataPointer.assumingMemoryBound(to: UInt16.self)
            for i in 0..<vocabulary {
                let value = Self.widened(pointer[base + i * step])
                if value > bestValue {
                    bestValue = value
                    best = i
                }
            }
            #endif
        default:
            let pointer = logits.dataPointer.assumingMemoryBound(to: Float32.self)
            for i in 0..<vocabulary where pointer[base + i * step] > bestValue {
                bestValue = pointer[base + i * step]
                best = i
            }
        }
        return best
    }
}
