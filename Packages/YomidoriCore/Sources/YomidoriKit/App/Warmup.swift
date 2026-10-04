import CoreGraphics
import Foundation
import YomidoriCore
import YomidoriDictionary

/// What is slow the first time and never again, done once at launch so the first page reads
/// as fast as the second: the recognizers' text models, which load only once there is text
/// to read, so the page is a rendered one with a few lines of Japanese on it; the analyzer's
/// first cut and the dictionary's first lookups through the same reading the drawer makes.
/// At a priority that gets it done before a finger can reach the button; a blank still at
/// utility priority, tried first, loaded the detectors and not the readers.
enum Warmup {
    static let text = "吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。"

    static func start() {
        Task.detached(priority: .userInitiated) {
            guard let image = DemoRenderer.verticalPage(text, size: CGSize(width: 600, height: 900))
            else { return }
            let still = Still(image: image)
            async let read = PageRecognition.read(still)
            async let words = PageReader.shared.read(text, with: .system)
            _ = await (read, words)
            _ = JMdict.bundled?.entries(matching: "本")
        }
    }
}
