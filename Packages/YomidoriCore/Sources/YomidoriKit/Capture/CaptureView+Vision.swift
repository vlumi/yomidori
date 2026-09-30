import SwiftUI
import YomidoriCore

/// Vision mode's picture as a view of the page's reading: a tap selects the word under the
/// finger, a long press stretches the selection to it, and the selection, made anywhere, is
/// outlined over its characters, on whichever page of the spread they are.
extension CaptureView {
    func tapWord(onPage index: Int, at point: CGPoint, in frame: CGRect) {
        guard let chunk = chunk(onPage: index, at: point, in: frame), chunk.isWord else { return }
        page.selectedRange = chunk.range
    }

    func extendWord(onPage index: Int, at point: CGPoint, in frame: CGRect) {
        guard let chunk = chunk(onPage: index, at: point, in: frame) else { return }
        guard let range = page.selectedRange else {
            if chunk.isWord { page.selectedRange = chunk.range }
            return
        }
        page.selectedRange =
            min(
                range.lowerBound, chunk.range.lowerBound)..<max(
                range.upperBound, chunk.range.upperBound)
    }

    /// The chunk of the reading under a point on a page; nil until the page is read.
    private func chunk(onPage index: Int, at point: CGPoint, in frame: CGRect)
        -> PageReading.Chunk?
    {
        guard let reading = page.reading, !selection.looking,
            spreadPages.indices.contains(index)
        else { return nil }
        let vision = VisionPage(lines: spreadPages[index].lines)
        guard let hit = vision.character(at: point, in: frame) else { return nil }
        let offset = offset(ofPage: index) + vision.starts[hit.line] + hit.character
        return reading.chunk(at: page.fixes.map(offset: offset))
    }

    /// The spread's pages as Vision mode draws them: each page's lines, the ones the
    /// selection touches lit, and one box per line over the selected characters.
    var visionSheets: [StillView.Sheet] {
        spreadPages.enumerated().compactMap { index, sheet in
            sheet.still.map {
                StillView.Sheet(
                    still: $0, lines: sheet.lines, selected: selectedLines(onPage: index),
                    highlights: selectionBoxes(onPage: index))
            }
        }
    }

    /// The spread's pages as Close-up draws them: the square read up close, on its page.
    var closeUpSheets: [StillView.Sheet] {
        spreadPages.enumerated().compactMap { index, sheet in
            sheet.still.map {
                StillView.Sheet(
                    still: $0, lines: sheet.lines, selected: [],
                    highlights: closeUp.flatMap { $0.page == index ? [$0.box] : nil } ?? [])
            }
        }
    }

    /// The selection over a page's Vision lines, one box per line it touches, normalized
    /// like them. Not on a page with a fix in it, whose characters are no longer the
    /// lines'; there the lines light whole.
    private func selectionBoxes(onPage index: Int) -> [CGRect] {
        guard mode == .vision, let range = page.selectedRange, !page.fixes.hasFixes(onPage: index)
        else { return [] }
        let vision = VisionPage(lines: spreadPages[index].lines)
        return vision.lines.indices.compactMap { line in
            let start = page.fixes.fixedOffset(ofPage: index) + vision.starts[line]
            let span = start..<(start + vision.lines[line].text.count)
            let overlap = span.clamped(to: range)
            guard !overlap.isEmpty else { return nil }
            return vision.lines[line].box(
                ofCharacters: (overlap.lowerBound - start)..<(overlap.upperBound - start))
        }
    }

    /// The lines of a page the selection touches, lit as a whole.
    private func selectedLines(onPage index: Int) -> Set<Int> {
        guard mode == .vision, let range = page.selectedRange else { return [] }
        let lines = spreadPages[index].lines
        let vision = VisionPage(lines: lines)
        return Set(
            vision.lines.indices.filter { line in
                let start = offset(ofPage: index) + vision.starts[line]
                let span = page.fixes.map(start..<(start + vision.lines[line].text.count))
                return span.overlaps(range)
            }.compactMap { lines.firstIndex(of: vision.lines[$0]) })
    }

    /// Where a page starts in the text of all the pages together.
    func offset(ofPage index: Int) -> Int {
        Spread.offset(ofPage: index, in: pageTexts)
    }

    /// Where the page on screen starts in the text of all the pages together.
    var pageOffset: Int {
        offset(ofPage: pages.count)
    }

    /// Which side the next page lies on: left of columns, under rows, by the first page; left
    /// when Vision found no lines to tell by, as a paperback's is.
    var spreadSide: SpreadLayout.Side {
        if let chosen = page.nextSide { return chosen }
        let lines = spreadPages.first?.lines ?? []
        return lines.isEmpty
            ? .left : SpreadLayout.side(forVertical: SpreadLayout.isVertical(lines))
    }

    /// The second page round the first: left, right, below, and left again.
    func moveNextPage() {
        let sides = SpreadLayout.Side.allCases
        let current = sides.firstIndex(of: spreadSide) ?? 0
        page.nextSide = sides[(current + 1) % sides.count]
    }
}
