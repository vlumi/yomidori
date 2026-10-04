import Foundation

/// The mora after which the pitch drops; 0 when it never does (平板).
public struct PitchAccent: Equatable, Sendable {
    public let downstep: Int

    public init(downstep: Int) {
        self.downstep = downstep
    }

    /// A small ゃゅょぁぃぅぇぉゎ joins the kana before it; っ, ん and ー stand alone.
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

    /// Every pattern a reading of `count` morae can take: flat, then a drop after each mora.
    public static func patterns(forMoraCount count: Int) -> [PitchAccent] {
        (0...max(count, 1)).map(PitchAccent.init(downstep:))
    }

    /// Flat starts low and stays high; a drop after the first mora starts high and stays low;
    /// a drop after mora n is low, high up to n, low after.
    public func highs(forMoraCount count: Int) -> [Bool] {
        (1...max(count, 1)).map { mora in
            if downstep == 0 { return mora > 1 }
            if downstep == 1 { return mora == 1 }
            return mora > 1 && mora <= downstep
        }
    }

    /// How each mora is drawn: high or low, with the fall after it where the pitch drops
    /// (after the last mora too, when the drop comes on what follows), and the rise before
    /// it where the pitch climbs.
    public struct Mark: Equatable, Sendable {
        public let high: Bool
        public let dropsAfter: Bool
        public let risesBefore: Bool
    }

    public func marks(forMoraCount count: Int) -> [Mark] {
        let highs = highs(forMoraCount: count)
        return highs.indices.map { index in
            let last = index + 1 == highs.count
            return Mark(
                high: highs[index],
                dropsAfter: highs[index] && (last ? downstep == index + 1 : !highs[index + 1]),
                risesBefore: !highs[index] && !last && highs[index + 1])
        }
    }

    private static let smallKana: Set<Character> = [
        "ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ゎ",
        "ャ", "ュ", "ョ", "ァ", "ィ", "ゥ", "ェ", "ォ", "ヮ",
    ]
}
