import CoreGraphics
import Foundation

/// The union of the recognized lines whose text is part of the sentence, in image pixels;
/// nil when none matches.
public enum LineCrop {
    public static func rect(
        for sentence: String, lines: [RecognizedLine], imageSize: CGSize
    ) -> CGRect? {
        let target = sentence.filter { !$0.isWhitespace }
        let matching = lines.filter { matches($0.text.filter { !$0.isWhitespace }, in: target) }
        guard !matching.isEmpty else { return nil }
        let union = matching.map { TextGeometry.imageRect(for: $0.box, imageSize: imageSize) }
            .reduce(CGRect.null) { $0.union($1) }
        let thickness =
            matching.map { min($0.box.width * imageSize.width, $0.box.height * imageSize.height) }
            .min() ?? 0
        return TextGeometry.padded(union, by: thickness * 0.8, in: imageSize)
    }

    /// A line belongs when a run of it is in the sentence: all of a short line, six characters
    /// of a longer one (the line carrying the sentence's end shares only that much), or six
    /// tenths of the shorter, since recognizer and sentence rarely agree on every character.
    static func matches(_ line: String, in sentence: String) -> Bool {
        guard line.count >= 2 else { return false }
        if sentence.contains(line) { return true }
        let run = longestCommonRun(line, sentence)
        return run >= min(6, line.count)
            || run >= Int((Double(min(line.count, sentence.count)) * 0.6).rounded(.up))
    }

    private static func longestCommonRun(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var previous = [Int](repeating: 0, count: b.count + 1)
        var best = 0
        for i in 1...max(a.count, 1) where i <= a.count {
            var current = [Int](repeating: 0, count: b.count + 1)
            for j in 1...max(b.count, 1) where j <= b.count && a[i - 1] == b[j - 1] {
                current[j] = previous[j - 1] + 1
                best = max(best, current[j])
            }
            previous = current
        }
        return best
    }
}
