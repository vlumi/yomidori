import SwiftUI
import YomidoriCore

/// Vision mode's picture as a view of the page's reading: a tap selects the word under the
/// finger, a long press stretches the selection to it, and the selection, made anywhere, is
/// outlined over its characters.
extension CaptureView {
    func tapWord(at point: CGPoint, in frame: CGRect) {
        guard let chunk = chunk(at: point, in: frame), chunk.isWord else { return }
        page.selectedRange = chunk.range
    }

    func extendWord(at point: CGPoint, in frame: CGRect) {
        guard let chunk = chunk(at: point, in: frame) else { return }
        guard let range = page.selectedRange else {
            if chunk.isWord { page.selectedRange = chunk.range }
            return
        }
        page.selectedRange =
            min(
                range.lowerBound, chunk.range.lowerBound)..<max(
                range.upperBound, chunk.range.upperBound)
    }

    /// The chunk of the reading under a point on the picture; nil until the page is read.
    private func chunk(at point: CGPoint, in frame: CGRect) -> PageReading.Chunk? {
        guard let reading = page.reading, !selection.looking else { return nil }
        let vision = VisionPage(lines: lines)
        guard let hit = vision.character(at: point, in: frame) else { return nil }
        let offset = pageOffset + vision.starts[hit.line] + hit.character
        return reading.chunk(at: TextFix.map(offset: offset, through: page.fixes))
    }

    /// The selection over Vision's lines, one box per line it touches, normalized like them.
    var selectionBoxes: [CGRect] {
        guard mode == .vision, let range = page.selectedRange, page.fixes.isEmpty else { return [] }
        let vision = VisionPage(lines: lines)
        return vision.lines.indices.compactMap { index in
            let start = pageOffset + vision.starts[index]
            let line = start..<(start + vision.lines[index].text.count)
            let overlap = line.clamped(to: range)
            guard !overlap.isEmpty else { return nil }
            return vision.lines[index].box(
                ofCharacters: (overlap.lowerBound - start)..<(overlap.upperBound - start))
        }
    }

    /// The lines the selection touches, lit as a whole.
    var selectedLines: Set<Int> {
        guard mode == .vision, let range = page.selectedRange else { return [] }
        let vision = VisionPage(lines: lines)
        return Set(
            vision.lines.indices.filter { index in
                let start = pageOffset + vision.starts[index]
                return (start..<(start + vision.lines[index].text.count)).overlaps(range)
            }.compactMap { lines.firstIndex(of: vision.lines[$0]) })
    }

    /// Where the page on screen starts in the text of all the pages together.
    var pageOffset: Int {
        guard let current = currentTranscript else { return 0 }
        return Spread.offset(ofPage: pages.count, in: pages.map(\.transcript) + [current])
    }
}
