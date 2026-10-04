import Foundation

/// The order the card list shows its cards in, newest or highest first, and the sections
/// it falls into: by rank, or by the month a card was made or last changed.
public enum CardSort: String, CaseIterable, Codable, Sendable {
    case rank
    case created
    case modified

    /// A section's identity: a rank, or the first day of a month.
    public enum Group: Hashable, Sendable {
        case rank(Rank)
        case month(Date)
    }

    public struct Section: Equatable, Sendable {
        public let group: Group
        public let cards: [Card]
    }

    /// The cards in sections, each sorted within; empty sections are left out.
    public func sections(_ cards: [Card], calendar: Calendar = .current) -> [Section] {
        switch self {
        case .rank:
            let byRank = Dictionary(grouping: cards, by: \.rank)
            return Rank.allCases.reversed().compactMap { rank in
                byRank[rank].map { Section(group: .rank(rank), cards: sorted($0)) }
            }
        case .created, .modified:
            let byMonth = Dictionary(grouping: cards) { card -> Date in
                let date = date(of: card)
                return calendar.dateInterval(of: .month, for: date)?.start ?? date
            }
            return byMonth.keys.sorted(by: >).map { month in
                Section(group: .month(month), cards: sorted(byMonth[month] ?? []))
            }
        }
    }

    /// Within a section: the newest first by the date sorted on, a rank's by the time of
    /// its last change, so what moved last is at the top.
    private func sorted(_ cards: [Card]) -> [Card] {
        cards.sorted { date(of: $0) > date(of: $1) }
    }

    private func date(of card: Card) -> Date {
        self == .created ? card.created : card.modified
    }
}
