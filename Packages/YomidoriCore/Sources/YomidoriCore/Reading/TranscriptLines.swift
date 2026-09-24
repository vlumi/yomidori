import Foundation

public struct TranscriptLines: Sendable {
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

    public func index(inLine line: Int, offset: Int, in transcript: String) -> String.Index {
        transcript.index(starts[line], offsetBy: offset)
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
