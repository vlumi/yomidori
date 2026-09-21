import Foundation
import YomidoriCore

struct SentenceKeeper {
    let transcript: String
    let transcriptLines: TranscriptLines
    let tokenLines: [[Token]]
    let stills: [Still]
    let currentLines: [RecognizedLine]
    let source: String?

    func sighting(for word: FoundWord, archived: inout [UUID: UUID]) -> Sighting? {
        guard let line = tokenLines.firstIndex(where: { $0.contains(word.first) }) else {
            return nil
        }
        let found = transcriptLines.sentence(around: word.first, onLine: line, in: transcript)
        return Sighting(
            sentence: found.sentence.text, surface: word.surface,
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
