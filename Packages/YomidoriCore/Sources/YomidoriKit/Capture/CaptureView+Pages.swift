import PhotosUI
import SwiftUI
import YomidoriCore

/// How a page comes and goes: the camera, the photo library, a paste; the next page, a start
/// over, a retake.
extension CaptureView {
    func takeStill() {
        Task { @MainActor in
            if let taken = await camera.takeStill() {
                camera.stop()
                still = taken
            }
        }
    }

    func addPage() {
        guard still != nil, let transcript = currentTranscript else { return }
        pages.append(Page(transcript: transcript))
        retake()
    }

    func startOver() {
        pages = []
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
        pages = []
        selection.text = ""
        selection.range = nil
        page.pasted = cleaned
    }

    static let longestPaste = 20_000

    func loadPicked() async {
        guard let picked, let data = try? await picked.loadTransferable(type: Data.self),
            let loaded = Still(data: data), !Task.isCancelled
        else { return }
        camera.stop()
        still = loaded
    }
}
