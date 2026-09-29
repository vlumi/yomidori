import Foundation

/// One accent phrase of a word or an expression: its kana and where its pitch drops. A
/// word is one phrase; an expression is several (けんとうが and つく for 見当がつく), each
/// rising and dropping on its own.
public struct PitchPhrase: Equatable, Hashable, Sendable {
    public let reading: String
    public let downstep: Int

    public init(reading: String, downstep: Int) {
        self.reading = reading
        self.downstep = downstep
    }

    public var accent: PitchAccent { PitchAccent(downstep: downstep) }

    /// The phrases as the dictionary keeps an estimate, `けんとうが:3|つく:1`; none if any
    /// part is not a kana and a drop within it.
    public static func parse(_ text: String) -> [PitchPhrase] {
        var phrases: [PitchPhrase] = []
        for part in text.split(separator: "|", omittingEmptySubsequences: false) {
            let fields = part.split(separator: ":", omittingEmptySubsequences: false)
            guard fields.count == 2, !fields[0].isEmpty, let downstep = Int(fields[1]),
                downstep >= 0, downstep <= PitchAccent.morae(of: String(fields[0])).count
            else { return [] }
            phrases.append(PitchPhrase(reading: String(fields[0]), downstep: downstep))
        }
        return phrases
    }
}
