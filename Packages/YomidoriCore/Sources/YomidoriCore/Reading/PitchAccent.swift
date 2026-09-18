import Foundation

/// Tokyo pitch accent, as dictionaries give it: the number of the mora after which
/// the pitch drops, 0 when it never does (平板). Drawn as a line over the morae that
/// are high, which is how learners' dictionaries print it.
public struct PitchAccent: Equatable, Sendable {
    public let downstep: Int

    public init(downstep: Int) {
        self.downstep = downstep
    }

    /// Kana split into morae: a small ゃゅょぁぃぅぇぉゎ joins the kana before it,
    /// everything else, っ, ん and the length mark included, stands alone.
    public static func morae(of reading: String) -> [String] {
        var result: [String] = []
        for character in reading {
            if Self.smallKana.contains(character), !result.isEmpty {
                result[result.count - 1].append(character)
            } else {
                result.append(String(character))
            }
        }
        return result
    }

    /// Whether each mora of the reading is high: flat starts low and stays high;
    /// a drop after the first mora starts high and stays low; a drop after mora n
    /// is low, high up to n, low after. The mora after the last one, the particle
    /// that would follow, is not drawn, so a final drop shows as a line to the end.
    public func highs(forMoraCount count: Int) -> [Bool] {
        (1...max(count, 1)).map { mora in
            if downstep == 0 { return mora > 1 }
            if downstep == 1 { return mora == 1 }
            return mora > 1 && mora <= downstep
        }
    }

    private static let smallKana: Set<Character> = [
        "ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ゎ",
        "ャ", "ュ", "ョ", "ァ", "ィ", "ゥ", "ェ", "ォ", "ヮ",
    ]
}
