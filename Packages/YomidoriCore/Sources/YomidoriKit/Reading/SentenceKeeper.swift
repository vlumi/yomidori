import Foundation
import YomidoriCore

struct SentenceKeeper {
    let transcript: String
    let transcriptLines: TranscriptLines
    let tokenLines: [[Token]]
    let source: String?

    /// `line` where the caller knows it; else the first line holding the word's first token.
    func sighting(for word: FoundWord, onLine known: Int? = nil) -> Sighting? {
        guard let line = known ?? tokenLines.firstIndex(where: { $0.contains(word.first) }) else {
            return nil
        }
        let found = transcriptLines.sentence(around: word.first, onLine: line, in: transcript)
        return Sighting(
            sentence: found.sentence.text,
            surface: WordFinder.pageForm(of: word, in: tokenLines[line]),
            offset: found.sentence.offset(of: found.start, in: transcript), source: source,
            date: Date())
    }
}
