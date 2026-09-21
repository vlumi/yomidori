import Foundation
import YomidoriCore
import YomidoriMangaOCR

/// Reads a tap up close: the crop by every engine on the page, the window by the
/// line reader when it is bundled.
enum CloseUpReader {
    static func read(_ still: Still, at geometry: CloseUpGeometry) async -> CaptureView.CloseUp? {
        guard let crop = still.cropped(to: geometry.crop) else { return nil }
        let lines = (try? await TextRecognizer.recognize(crop)) ?? []
        let transcript =
            LiveText.isSupported ? (try? await LiveText.analyze(crop))?.transcript ?? "" : ""
        let manga = MangaOCR.bundled.flatMap { reader in
            still.cropped(to: geometry.window).flatMap { try? reader.read($0.image) }
        }
        return CaptureView.CloseUp(
            box: TextGeometry.normalizedBox(for: geometry.crop, imageSize: still.size), crop: crop,
            vision: lines.map(\.text).joined(separator: " "),
            liveText: transcript.replacingOccurrences(of: "\n", with: " "), mangaOCR: manga)
    }
}
