import CoreGraphics
import Foundation
import YomidoriCore
import YomidoriDictionary

/// What is slow the first time and never again, done once at launch in the background, so
/// the first page reads as fast as the second: the dictionary opened and its statements
/// made, the analyzer's first cut, Vision's document model and Live Text's analyzer loaded
/// on a blank still. Nothing is kept; the loads are the frameworks' own.
enum Warmup {
    static func start() {
        Task.detached(priority: .utility) {
            _ = JMdict.bundled?.entries(matching: "本")
            _ = SystemTokenizer().tokens(in: "吾輩は猫である。")
            guard let still = blank() else { return }
            _ = try? await TextRecognizer.recognize(still)
            if LiveText.isSupported { _ = try? await LiveText.analyze(still) }
        }
    }

    /// A small white still, enough to run the recognizers over.
    private static func blank() -> Still? {
        guard
            let context = CGContext(
                data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        return context.makeImage().map(Still.init(image:))
    }
}
