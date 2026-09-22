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
    @Published var selected: Int?
    @Published var closeUp: CaptureView.CloseUp?
    @Published var zoom = Zoom()
    /// The still the lines and the analysis belong to; a return does not read it again.
    var recognizedStillID: UUID?
}
