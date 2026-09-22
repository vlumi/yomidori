import Foundation

/// The next cards to start, picked from the waiting stack in the order the reader chose.
public enum Lesson {
    public enum Order: String, CaseIterable, Sendable {
        case oldest
        case newest
        case random
        case common
    }

    /// `isCommon` marks the cards the dictionary calls common, which come first in that
    /// order and keep their age order among themselves.
    public static func pick<Generator: RandomNumberGenerator>(
        from waiting: [Card], order: Order, size: Int, isCommon: (Card) -> Bool = { _ in false },
        using generator: inout Generator
    ) -> [Card] {
        let oldestFirst = waiting.sorted { $0.created < $1.created }
        let ordered: [Card]
        switch order {
        case .oldest: ordered = oldestFirst
        case .newest: ordered = oldestFirst.reversed()
        case .random: ordered = oldestFirst.shuffled(using: &generator)
        case .common: ordered = oldestFirst.filter(isCommon) + oldestFirst.filter { !isCommon($0) }
        }
        return Array(ordered.prefix(max(size, 0)))
    }

    public static func pick(
        from waiting: [Card], order: Order, size: Int, isCommon: (Card) -> Bool = { _ in false }
    ) -> [Card] {
        var generator = SystemRandomNumberGenerator()
        return pick(from: waiting, order: order, size: size, isCommon: isCommon, using: &generator)
    }
}
