import SwiftUI
import VisionKit
import YomidoriCore

/// The page as it stands, owned above the capture screen so a swipe back to home and a
/// return find the still, the pages, the mode and the zoom as they were left.
@MainActor
final class CaptureState: ObservableObject {
    @Published var still: Still?
    @Published var pages: [CaptureView.Page] = []
    @Published var mode: CaptureView.Mode = .liveText
    @Published var lines: [RecognizedLine] = []
    @Published var analysis: ImageAnalysis?
    /// The page's text when it did not come from Live Text: the demo's rendered page.
    @Published var transcript: String?
    /// Text pasted in place of a page, cleaned; nil while a photo or the camera is up.
    @Published var pasted: String?
    /// The page read into its words, over `readingText`; nil while it is being read.
    @Published var reading: PageReading?
    /// The selection everything shows: the strip, the picture and the drawer. Characters of
    /// the reading's text, whole chunks.
    @Published var selectedRange: Range<Int>?
    /// The reader's corrections to the page's text, cleared with a new page.
    @Published var fixes: [TextFix] = []
    /// What `reading` was read from, the tokenizer and the text, so a return to the page
    /// does not read it again.
    var readingKey: String?

    /// A new page, or a new spread: the reading and the selection go, and so do the fixes
    /// unless earlier pages of the same spread still carry them.
    func newPage(keepingFixes: Bool = false) {
        reading = nil
        readingKey = nil
        selectedRange = nil
        if !keepingFixes { fixes = [] }
    }
    @Published var closeUp: CaptureView.CloseUp?
    @Published var zoom = Zoom()
    /// The still the lines and the analysis belong to; a return does not read it again.
    var recognizedStillID: UUID?
}
