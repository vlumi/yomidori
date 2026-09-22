import Foundation

/// How far a card has come, in birds: bands on the reading's stability. The nest, the shelf,
/// is the floor; the egg waits; nothing retires, a migrating bird still comes back.
public enum Rank: Int, CaseIterable, Comparable, Sendable {
    case nest
    case egg
    case hatchling
    case chick
    case fledgling
    case flying
    case migrating

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
    public var rank: Rank {
        if shelved { return .nest }
        guard started != nil else { return .egg }
        return review.map { Rank(stability: $0.stability) } ?? .hatchling
    }
}
