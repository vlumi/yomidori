import Foundation

/// How far a card has come, in birds: bands on the reading's stability. The nest, the shelf,
/// is the floor; the egg waits; nothing retires, a migrating bird still comes back.
public enum Rank: Int, CaseIterable, Comparable, Sendable {
    /// Shelved: outside the climb, so no number of its own.
    case nest = -1
    /// Waiting for a lesson: the climb's 0.
    case egg = 0
    case hatchling
    case chick
    case fledgling
    case flying
    case migrating

    /// The number a card shows for its rank, 0 for the egg to 5 for the migrating bird; the
    /// nest has none.
    public var number: Int? { self == .nest ? nil : rawValue }

    /// Its place in `allCases`, the nest first: what a stored count is indexed by.
    public var index: Int { rawValue + 1 }

    /// The days of stability a rank begins at.
    public static let bands: [(rank: Rank, days: Double)] = [
        (.hatchling, 0), (.chick, 7), (.fledgling, 30), (.flying, 120), (.migrating, 365),
    ]

    public init(stability: Double) {
        self = Self.bands.last { stability >= $0.days }?.rank ?? .hatchling
    }

    public static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension Card {
    /// Waiting is the egg, shelved the nest; a started card ranks by its reading's stability,
    /// a hatchling until the first answer.
    /// The card stands where its weakest question stands: the lowest of the reading's and
    /// the meaning's ranks, and the pitch's once it has been asked — a card with no pitch
    /// to ask is not held to a question it never gets.
    public var rank: Rank {
        var asked: [Question] = [.reading, .meaning]
        if pitchReview != nil { asked.append(.pitch) }
        return asked.map(rank(for:)).min() ?? rank(for: .reading)
    }

    /// The rank of one of the card's questions, each climbing at its own pace, a hatchling
    /// until first answered.
    public func rank(for question: Question) -> Rank {
        if shelved { return .nest }
        guard started != nil else { return .egg }
        return state(for: question).map { Rank(stability: $0.stability) } ?? .hatchling
    }
}
