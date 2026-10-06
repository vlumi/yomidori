import Foundation

/// The questions of one review in the order they are asked, and the rules of asking: the
/// front item is up; answered, it leaves, and a miss comes back a few questions on until it
/// is right; a question asked once already is a repeat, to finish right, and counts for
/// nothing. A card changed under the review (answered, its sentence corrected) is replaced
/// wherever it still stands.
public struct ReviewQueue: Equatable, Sendable {
    public private(set) var items: [ReviewItem]
    /// The questions asked once already this review, by card and question.
    private var asked: Set<Asked> = []

    private struct Asked: Hashable {
        let card: UUID
        let question: Question
    }

    /// How many questions a miss comes back after, or at the end of a shorter queue.
    public static let missComesBackAfter = 3

    public init(_ items: [ReviewItem]) {
        self.items = items
    }

    public var current: ReviewItem? { items.first }
    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }

    /// Whether `item` is the one up: two buttons pressed at once both answer the same item,
    /// and only the first lands.
    public func isCurrent(_ item: ReviewItem) -> Bool {
        current?.card.id == item.card.id && current?.question == item.question
    }

    /// Whether `item` was asked once already this review.
    public func isRepeat(_ item: ReviewItem) -> Bool {
        asked.contains(Asked(card: item.card.id, question: item.question))
    }

    /// The item up answered: gone from the front and marked asked; `reviewed`, the card as
    /// the answer left it, replaces the card in every question still queued; a miss comes
    /// back `missComesBackAfter` questions on.
    public mutating func answered(_ item: ReviewItem, grade: Grade, card reviewed: Card?) {
        guard isCurrent(item) else { return }
        asked.insert(Asked(card: item.card.id, question: item.question))
        items.removeFirst()
        if let reviewed { replace(card: reviewed) }
        if grade == .again {
            let again = ReviewItem(card: reviewed ?? item.card, question: item.question)
            items.insert(again, at: min(Self.missComesBackAfter, items.count))
        }
    }

    /// The card, as it is now, in every question of it still queued.
    public mutating func replace(card: Card) {
        items = items.map {
            $0.card.id == card.id ? ReviewItem(card: card, question: $0.question) : $0
        }
    }

    /// Every question of the card gone, as when it is sent back to waiting.
    public mutating func remove(card id: UUID) {
        items.removeAll { $0.card.id == id }
    }
}
