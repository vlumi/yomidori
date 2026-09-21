import Foundation

/// A transcript as its lines, empty ones dropped as the word strip shows them, with
/// the way back from a position in the transcript to the line it is on.
public struct TranscriptLines {
    public let lines: [String]
    /// Where each line starts in the transcript.
    public let starts: [String.Index]

    public init(_ transcript: String) {
        var lines: [String] = []
        var starts: [String.Index] = []
        for line in transcript.split(separator: "\n", omittingEmptySubsequences: true) {
            lines.append(String(line))
            starts.append(line.startIndex)
        }
        self.lines = lines
        self.starts = starts
    }

    /// The line a character offset into the transcript falls on; nil past the end.
    public func lineIndex(atOffset offset: Int, in transcript: String) -> Int? {
        guard offset >= 0, offset < transcript.count else { return nil }
        let index = transcript.index(transcript.startIndex, offsetBy: offset)
        return starts.lastIndex { $0 <= index }
    }

    /// The transcript position of a character offset into one of the lines.
    public func index(inLine line: Int, offset: Int, in transcript: String) -> String.Index {
        transcript.index(starts[line], offsetBy: offset)
    }
}

extension TranscriptLines {
    /// The sentence around a token on one of the lines, with where the token starts in
    /// the transcript, so a kept sentence knows its word's place.
    public func sentence(around token: Token, onLine line: Int, in transcript: String)
        -> (sentence: Sentence, start: String.Index)
    {
        let text = lines[line]
        let offset = text.distance(from: text.startIndex, to: token.range.lowerBound)
        let start = index(inLine: line, offset: offset, in: transcript)
        return (Sentence.around(start, in: transcript), start)
    }
}
