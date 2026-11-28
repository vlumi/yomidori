import Foundation

/// The ranks by day, replayed from the cards: every card's answers and moves in date order
/// through the scheduler, the counts taken at the start of each day from the day after the
/// first card's to `today`. Nothing is kept: every device shows the same history, and a
/// card from a backup brings its own. A card from before moves were kept is read from where
/// it stands now: started at its start or its first answer, and sent to waiting or shelved
/// from its last answer on.
public enum RankHistory {
    fileprivate enum Event {
        case appeared
        case answer(Question, Grade)
        case move(CardMove.Standing)

        /// On one date, the card appears, is answered, and then moved.
        var order: Int {
            switch self {
            case .appeared: return 0
            case .answer: return 1
            case .move: return 2
            }
        }
    }

    private struct Step {
        let date: Date
        let card: Int
        let event: Event
    }

    /// The counts carried along, changed by each step from the card's old standing to its new.
    private struct Counts {
        var all = Array(repeating: 0, count: Rank.allCases.count)
        var byQuestion: [Int: [Int]] = Dictionary(
            uniqueKeysWithValues: Question.allCases.map {
                ($0.rawValue, Array(repeating: 0, count: Rank.allCases.count))
            })

        mutating func add(_ card: Card, _ sign: Int) {
            all[card.rank.index] += sign
            for question in Question.allCases where question != .reading || card.asksReading {
                byQuestion[question.rawValue]?[card.rank(for: question).index] += sign
            }
        }
    }

    public static func replay(_ cards: [Card], through today: Date, calendar: Calendar = .current)
        -> [RankSnapshot]
    {
        let steps = steps(of: cards)
        guard let first = steps.first else { return [] }
        var standing = cards.map(\.blank)
        var present = Array(repeating: false, count: cards.count)
        var counts = Counts()
        var snapshots: [RankSnapshot] = []
        let last = calendar.startOfDay(for: today)
        var next = 0
        var day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: first.date))
        while let start = day, start <= last {
            while next < steps.count, steps[next].date < start {
                let step = steps[next]
                if present[step.card] { counts.add(standing[step.card], -1) }
                present[step.card] = true
                standing[step.card].apply(step.event, at: step.date)
                counts.add(standing[step.card], 1)
                next += 1
            }
            snapshots.append(
                RankSnapshot(day: start, counts: counts.all, byQuestion: counts.byQuestion))
            day = calendar.date(byAdding: .day, value: 1, to: start)
        }
        return snapshots
    }

    private static func steps(of cards: [Card]) -> [Step] {
        var steps: [Step] = []
        for (index, card) in cards.enumerated() {
            steps.append(Step(date: card.created, card: index, event: .appeared))
            for entry in card.log {
                steps.append(
                    Step(date: entry.date, card: index, event: .answer(entry.question, entry.grade))
                )
            }
            for move in card.movesForReplay {
                steps.append(Step(date: move.date, card: index, event: .move(move.standing)))
            }
        }
        return steps.sorted {
            ($0.date, $0.event.order, $0.card) < ($1.date, $1.event.order, $1.card)
        }
    }
}

extension Card {
    /// The card before anything was done to it: waiting, with no schedule.
    fileprivate var blank: Card {
        Card(
            id: id, headword: headword, reading: reading, entryID: entryID, sightings: [],
            created: created)
    }

    fileprivate mutating func apply(_ event: RankHistory.Event, at date: Date) {
        switch event {
        case .appeared:
            break
        case .answer(let question, let grade):
            setState(FSRS.review(state(for: question), grade: grade, at: date), for: question)
        case .move(.started):
            start(at: date)
        case .move(.waiting):
            sendToWaiting(at: date)
        case .move(.shelved):
            shelve(at: date)
        }
    }

    /// The moves as kept, filled in for a card from before they were: a start where the
    /// answers say there was one, and where the card stands now from its last answer on.
    fileprivate var movesForReplay: [CardMove] {
        var moves = moves
        if let startedAt = started ?? log.first?.date,
            !moves.contains(where: { $0.standing == .started && $0.date <= startedAt })
        {
            moves.append(CardMove(date: startedAt, standing: .started))
        }
        let since = [log.last?.date, moves.last?.date].compactMap { $0 }.max() ?? created
        if shelved, !moves.contains(where: { $0.standing == .shelved && $0.date >= since }) {
            moves.append(CardMove(date: since, standing: .shelved))
        } else if isWaiting, !log.isEmpty,
            !moves.contains(where: { $0.standing == .waiting && $0.date >= since })
        {
            moves.append(CardMove(date: since, standing: .waiting))
        }
        return moves.sorted { $0.date < $1.date }
    }
}
