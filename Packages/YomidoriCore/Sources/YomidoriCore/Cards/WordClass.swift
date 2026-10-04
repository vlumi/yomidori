import Foundation

/// The broad kind of word a card is, read off the dictionary's parts of speech, for a
/// filter over the cards: JMdict's dozens of codes fold into five classes and a rest.
public enum WordClass: String, CaseIterable, Codable, Sendable {
    case noun
    case verb
    case adjective
    case adverb
    case expression
    case other

    /// The classes a sense's codes name; a する-noun is a noun and a verb both.
    public static func of(partsOfSpeech codes: [String]) -> Set<WordClass> {
        var classes: Set<WordClass> = []
        for code in codes {
            switch code {
            case "exp": classes.insert(.expression)
            case "adv", "adv-to": classes.insert(.adverb)
            case "pn", "num", "ctr": classes.insert(.noun)
            case let code where code.hasPrefix("n"): classes.insert(.noun)
            case let code where code.hasPrefix("adj"): classes.insert(.adjective)
            case let code where code.hasPrefix("v") || code == "aux-v": classes.insert(.verb)
            default: classes.insert(.other)
            }
        }
        // The rest counts only where nothing else does.
        if classes.count > 1 { classes.remove(.other) }
        return classes
    }
}
