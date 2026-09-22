import Foundation

public struct TranscriptLines {
    public let lines: [String]
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

    public func lineIndex(atOffset offset: Int, in transcript: String) -> Int? {
        guard offset >= 0, offset < transcript.count else { return nil }
        let index = transcript.index(transcript.startIndex, offsetBy: offset)
        return starts.lastIndex { $0 <= index }
    }

    public func index(inLine line: Int, offset: Int, in transcript: String) -> String.Index {
        transcript.index(starts[line], offsetBy: offset)
    }

    /// The line a selection on the page shown falls in. The selection's indices belong to
    /// `page`, whose text starts `pageOffset` characters into the joined transcript.
    public func lineIndex(
        ofSelection range: Range<String.Index>?, in page: String, pageOffset: Int,
        transcript: String
    ) -> Int? {
        guard let range, range.lowerBound <= page.endIndex else { return nil }
        let offset = pageOffset + page.distance(from: page.startIndex, to: range.lowerBound)
        return lineIndex(atOffset: offset, in: transcript)
    }
}

extension TranscriptLines {
    /// `token.range` indexes `lines[line]`, the String the tokenizer was given, not the transcript.
    public func sentence(around token: Token, onLine line: Int, in transcript: String)
        -> (sentence: Sentence, start: String.Index)
    {
        let text = lines[line]
        let offset = text.distance(from: text.startIndex, to: token.range.lowerBound)
        let start = index(inLine: line, offset: offset, in: transcript)
        return (Sentence.around(start, in: transcript), start)
    }
}
