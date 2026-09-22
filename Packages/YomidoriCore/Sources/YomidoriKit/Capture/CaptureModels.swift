import SwiftUI
import YomidoriCore

extension CaptureView {
    enum Mode: Hashable {
        case vision
        case liveText
        case closeUp
    }

    struct Page {
        let still: Still
        let transcript: String
    }

    /// One reading up close: the square around a tap, and what each engine made of it.
    struct CloseUp {
        let box: CGRect
        let crop: Still
        let vision: String
        let liveText: String
        /// manga-ocr's reading of a window around the tap; nil where the models are not bundled.
        let mangaOCR: String?
    }
}
