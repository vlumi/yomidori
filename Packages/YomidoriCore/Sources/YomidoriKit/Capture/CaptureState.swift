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
    /// The reader's corrections, each page's own over the text it was made on, cleared with
    /// a new spread.
    @Published var fixes = SpreadFixes()
    /// What `reading` was read from, the tokenizer and the text, so a return to the page
    /// does not read it again.
    var readingKey: String?

    /// The selection stretched to a chunk: from where it starts to the chunk, whichever way;
    /// with nothing selected, the chunk itself if it is a word.
    func extendSelection(to chunk: PageReading.Chunk) {
        guard let range = selectedRange else {
            if chunk.isWord { selectedRange = chunk.range }
            return
        }
        selectedRange =
            min(
                range.lowerBound, chunk.range.lowerBound)..<max(
                range.upperBound, chunk.range.upperBound)
    }

    /// A new page, or a new spread: the reading and the selection go, and so do the fixes
    /// unless earlier pages of the same spread still carry them.
    func newPage(keepingFixes: Bool = false) {
        reading = nil
        readingKey = nil
        selectedRange = nil
        if !keepingFixes { fixes = SpreadFixes() }
    }
    @Published var zoom = Zoom()
    /// Where the reader put the second page; nil for where the text's direction puts it.
    @Published var nextSide: SpreadLayout.Side?
    /// The still the lines and the analysis belong to; a return does not read it again.
    var recognizedStillID: UUID?
}
