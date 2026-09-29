import SwiftUI
import VisionKit
import YomidoriCore

extension CaptureView {
    enum Mode: Hashable {
        case vision
        case liveText
        case closeUp
    }

    /// An earlier page of the spread, kept whole: its photo and what both engines read on it,
    /// so it can be shown and read again in whichever engine is chosen.
    struct Page {
        let still: Still?
        let lines: [RecognizedLine]
        let analysis: ImageAnalysis?
        /// The text when it came from neither engine: the demo's page.
        let transcript: String?
    }

    /// Two pages at most: a book's spread.
    static let pagesInASpread = 2

    /// One reading up close: the square around a tap, and what each engine made of it.
    struct CloseUp {
        let box: CGRect
        let crop: Still
        let vision: String
        let liveText: String
        /// manga-ocr's reading of a window around the tap; nil where the models are not bundled.
        let mangaOCR: String?
        /// The page of the spread it was read on.
        var page = 0
    }
}
