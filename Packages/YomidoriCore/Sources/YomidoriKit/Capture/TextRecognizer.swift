import Vision
import YomidoriCore
import os

/// Vision's document request: lines with their boxes, vertical columns included, and each
/// character's box, for a tap to land on a character. A dense page — small print, a full
/// page in the frame — is read again in four tiles, the same page seen closer, since
/// Vision works at a size of its own and on the whole frame the furigana melt into the kanji;
/// the tiles' characters go into the whole page's lines (`TileStitch`).
enum TextRecognizer {
    /// Characters closer together than this share of the frame's long side: small print.
    static let densePrint: CGFloat = 1 / 40
    static let tileOverlap: CGFloat = 0.08
    private static let log = Logger(subsystem: "fi.misaki.yomidori", category: "vision")

    static func recognize(_ still: Still) async throws -> [RecognizedLine] {
        let image = still.image
        let whole = try await lines(in: image)
        let size = CGSize(width: image.width, height: image.height)
        let aspect = size.width / size.height
        let usual = TileStitch.usualSize(of: whole, aspect: aspect)
        let skeleton = TileStitch.droppingRubyLines(whole, usual: usual, aspect: aspect)
        // The print's size on the frame: how far apart the characters stand.
        let pitch = TileStitch.characterPitch(of: skeleton, aspect: aspect) * size.height
        guard pitch > 0, pitch < max(size.width, size.height) * densePrint else { return skeleton }
        let started = ContinuousClock.now
        let glyphs = try await tileGlyphs(of: image, size: size)
        let stitched = TileStitch.stitch(skeleton, with: glyphs, aspect: aspect)
        let took = ContinuousClock.now - started
        log.info("dense page, pitch \(Int(pitch)) px: \(glyphs.count) tile characters in \(took)")
        return stitched
    }

    /// The page in four overlapping tiles, read at once, each tile's characters placed on
    /// the page.
    private static func tileGlyphs(of image: CGImage, size: CGSize) async throws -> [TileGlyph] {
        let tile = CGSize(width: size.width / 2, height: size.height / 2)
        var rects: [CGRect] = []
        for column in 0..<2 {
            for row in 0..<2 {
                let x0 = max(0, tile.width * CGFloat(column) - tile.width * tileOverlap)
                let x1 = min(
                    size.width, tile.width * CGFloat(column + 1) + tile.width * tileOverlap)
                let y0 = max(0, tile.height * CGFloat(row) - tile.height * tileOverlap)
                let y1 = min(
                    size.height, tile.height * CGFloat(row + 1) + tile.height * tileOverlap)
                rects.append(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
            }
        }
        return try await withThrowingTaskGroup(of: [TileGlyph].self) { group in
            for rect in rects {
                guard let crop = image.cropping(to: rect) else { continue }
                group.addTask { try await glyphs(in: crop, at: rect, of: size) }
            }
            var all: [TileGlyph] = []
            for try await glyphs in group { all += glyphs }
            return all
        }
    }

    /// A tile's characters with their boxes moved from the tile to the page: Vision's boxes
    /// are normalized to the image it was given, y up; the tile's rectangle is in pixels, y
    /// down, as `cropping` wants it.
    private static func glyphs(in crop: CGImage, at rect: CGRect, of size: CGSize) async throws
        -> [TileGlyph]
    {
        try await lines(in: crop).flatMap { line in
            zip(line.text, line.characterBoxes).map { character, box in
                let page = CGRect(
                    x: (rect.minX + box.minX * rect.width) / size.width,
                    y: (size.height - rect.maxY + box.minY * rect.height) / size.height,
                    width: box.width * rect.width / size.width,
                    height: box.height * rect.height / size.height)
                let tile = CGPoint(
                    x: rect.midX / size.width, y: (size.height - rect.midY) / size.height)
                return TileGlyph(character: character, box: page, tile: tile)
            }
        }
    }

    private static func lines(in image: CGImage) async throws -> [RecognizedLine] {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "ja")]
        let observations = try await request.perform(on: image)
        return observations.flatMap { observation in
            observation.document.text.lines.map(line)
        }
    }

    private static func line(_ line: RecognizedTextObservation) -> RecognizedLine {
        guard let candidate = line.topCandidates(1).first else {
            return RecognizedLine(
                text: line.transcript, box: line.boundingRegion.boundingBox.cgRect,
                confidence: line.confidence)
        }
        let text = candidate.string
        var boxes: [CGRect] = []
        for index in text.indices {
            guard let box = candidate.boundingBox(for: index..<text.index(after: index)) else {
                boxes = []
                break
            }
            boxes.append(box.boundingBox.cgRect)
        }
        return RecognizedLine(
            text: text, box: line.boundingRegion.boundingBox.cgRect, confidence: line.confidence,
            characterBoxes: boxes
        ).droppingRuby()
    }
}
