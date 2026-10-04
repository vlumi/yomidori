import SwiftUI
import VisionKit
import YomidoriCore

extension CaptureView {
    enum Mode: Hashable {
        case vision
        case liveText
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

}
