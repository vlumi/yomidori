import PhotosUI
import SwiftUI
import VisionKit
import YomidoriCore

/// How a page comes and goes: the camera, the photo library, a paste; the next page, a start
/// over, a retake.
extension CaptureView {
    /// A frame that arrives after the page was filled some other way (a paste, a photo, the
    /// tab left and the camera stopped) is dropped.
    func takeStill() {
        Task { @MainActor in
            guard let taken = await camera.takeStill(), still == nil, page.pasted == nil else {
                return
            }
            camera.stop()
            still = taken
        }
    }

    func addPage() {
        guard still != nil, currentTranscript != nil, pages.count + 1 < Self.pagesInASpread
        else { return }
        pages.append(currentPage)
        retake()
    }

    /// The + pressed by mistake, or thought better of: the page taken last comes back as it
    /// was, read and all, and the camera rests.
    func backToPage() {
        guard still == nil, let last = pages.popLast() else { return }
        camera.stop()
        selection.clear()
        page.lines = last.lines
        page.analysis = last.analysis
        page.transcript = last.transcript
        page.recognizedStillID = last.still?.id
        page.still = last.still
    }

    func startOver() {
        pages = []
        page.nextSide = nil
        selection.pageTexts = [:]
        page.newPage()
        if still != nil {
            retake()
        }
    }

    /// Back to the camera at once: whatever was still reading the old page is cancelled with
    /// the page, and its result, should it come, is dropped.
    func retake() {
        recognizing = false
        selection.clear()
        page.selectedRange = nil
        still = nil
        page.pasted = nil
        picked = nil
        camera.start()
    }

    /// Pasted text read as a page: cleaned, cut to a long chapter, and put in the page's place.
    func paste(_ text: String) {
        let cleaned = Sanitize.text(text, limit: Self.longestPaste, keepsNewlines: true)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        camera.stop()
        page.clearPage()
        selection.clear()
        page.pasted = cleaned
    }

    static let longestPaste = 20_000

    func loadPicked() async {
        guard let picked, let data = try? await picked.loadTransferable(type: Data.self),
            let loaded = Still(data: data), !Task.isCancelled
        else { return }
        camera.stop()
        still = loaded
        // Loaded once: a return to the tab must not read the photo again.
        self.picked = nil
    }

    /// The page being read now, as the earlier ones are kept.
    var currentPage: Page {
        Page(still: still, lines: lines, analysis: analysis, transcript: page.transcript)
    }

    /// The spread's pages in reading order, the one taken last at the end.
    var spreadPages: [Page] {
        pages + [currentPage]
    }

    /// Each page's text in the engine chosen, one a page, in reading order; a paste is one.
    var pageTexts: [String] {
        if let pasted = page.pasted { return [pasted] }
        return spreadPages.enumerated().map { text(of: $1, at: $0) ?? "" }
    }

    /// A page's text: Vision's lines in Vision mode, Live Text's, or the one the page came
    /// with.
    func text(of sheet: Page, at index: Int) -> String? {
        if mode == .vision, !sheet.lines.isEmpty {
            return VisionPage(lines: sheet.lines).transcript
        }
        if let analysis = sheet.analysis, analysis.hasResults(for: .text) {
            // The interaction's text once it has it: Live Text's selection counts in that one.
            return selection.pageTexts[index] ?? analysis.transcript
        }
        return sheet.transcript
    }
}
