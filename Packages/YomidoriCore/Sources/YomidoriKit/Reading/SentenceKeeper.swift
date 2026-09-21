import Foundation
import YomidoriCore

/// Makes the sighting for a kept word: the sentence around it in the whole transcript
/// and the word's place in it, every page's still saved once, and the crop of the
/// sentence's lines where the page reader placed them.
struct SentenceKeeper {
    let transcript: String
    let transcriptLines: TranscriptLines
    let tokenLines: [[Token]]
    let stills: [Still]
    let currentLines: [RecognizedLine]
    let source: String?

    func sighting(for token: Token, archived: inout [UUID: UUID]) -> Sighting? {
        guard let line = tokenLines.firstIndex(where: { $0.contains(token) }) else { return nil }
        let found = transcriptLines.sentence(around: token, onLine: line, in: transcript)
        return Sighting(
            sentence: found.sentence.text, surface: token.surface,
            offset: found.sentence.offset(of: found.start, in: transcript),
            stillIDs: stillIDs(archived: &archived), cropID: cropID(for: found.sentence.text),
            source: source, date: Date())
    }

    private func stillIDs(archived: inout [UUID: UUID]) -> [UUID] {
        stills.compactMap { still in
            if let id = archived[still.id] { return id }
            guard let id = try? StillArchive.save(still) else { return nil }
            archived[still.id] = id
            return id
        }
    }

    private func cropID(for sentence: String) -> UUID? {
        guard let still = stills.last,
            let rect = LineCrop.rect(for: sentence, lines: currentLines, imageSize: still.size),
            let crop = still.cropped(to: rect)
        else { return nil }
        return try? StillArchive.save(crop)
    }
}
