import Foundation

/// How a card was answered. Two grades are enough for readings: either it came or
/// it did not. They map to FSRS's Again (1) and Good (3).
public enum Grade: String, Codable, Sendable {
    case again
    case good

    var rating: Double {
        self == .again ? 1 : 3
    }
}

/// What the scheduler remembers about a card: FSRS's stability (the days until
/// recall drops to 90 %) and difficulty (1 to 10), when it is due, when it was last
/// reviewed, and the counts. A card never reviewed has no state and is due at once.
public struct ReviewState: Hashable, Codable, Sendable {
    public var stability: Double
    public var difficulty: Double
    public var due: Date
    public var lastReview: Date
    public var reviews: Int
    public var lapses: Int

    public init(
        stability: Double, difficulty: Double, due: Date, lastReview: Date, reviews: Int,
        lapses: Int
    ) {
        self.stability = stability
        self.difficulty = difficulty
        self.due = due
        self.lastReview = lastReview
        self.reviews = reviews
        self.lapses = lapses
    }
}

/// FSRS-5, the free spaced repetition scheduler, with its published default
/// parameters and a desired retention of 90 %: fewer reviews for the same recall
/// than SM-2, which matters when the cards arrive as a stream from real reading.
/// Intervals are whole days, one at least; a review on the same day as the last one
/// uses the short-term rule.
public enum FSRS {
    public static let desiredRetention = 0.9
    static let decay = -0.5
    static let factor = 19.0 / 81.0
    static let day: TimeInterval = 86_400
    // swift-format-ignore: AlwaysUseLowerCamelCase
    static let w: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
        1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
    ]

    /// The probability the card is still recalled at `date`.
    public static func retrievability(of state: ReviewState, at date: Date) -> Double {
        let elapsed = max(0, date.timeIntervalSince(state.lastReview) / day)
        return pow(1 + factor * elapsed / state.stability, decay)
    }

    /// The state after answering with `grade` at `date`; `state` nil for a first review.
    public static func review(_ state: ReviewState?, grade: Grade, at date: Date) -> ReviewState {
        let rating = grade.rating
        var next: ReviewState
        if let state {
            let elapsedDays = date.timeIntervalSince(state.lastReview) / day
            let retrievability = retrievability(of: state, at: date)
            let stability: Double
            if elapsedDays < 1 {
                stability = state.stability * exp(w[17] * (rating - 3 + w[18]))
            } else if grade == .again {
                stability = min(
                    w[11] * pow(state.difficulty, -w[12]) * (pow(state.stability + 1, w[13]) - 1)
                        * exp(w[14] * (1 - retrievability)),
                    state.stability)
            } else {
                stability =
                    state.stability
                    * (exp(w[8]) * (11 - state.difficulty) * pow(state.stability, -w[9])
                        * (exp(w[10] * (1 - retrievability)) - 1) + 1)
            }
            next = state
            next.stability = max(stability, 0.01)
            next.difficulty = nextDifficulty(state.difficulty, rating: rating)
            next.reviews += 1
            if grade == .again { next.lapses += 1 }
        } else {
            next = ReviewState(
                stability: w[Int(rating) - 1], difficulty: initialDifficulty(rating: rating),
                due: date,
                lastReview: date, reviews: 1, lapses: grade == .again ? 1 : 0)
        }
        next.lastReview = date
        next.due = date.addingTimeInterval(interval(forStability: next.stability) * day)
        return next
    }

    /// Days until recall falls to the desired retention, whole and at least one.
    static func interval(forStability stability: Double) -> Double {
        let days = stability / factor * (pow(desiredRetention, 1 / decay) - 1)
        return max(1, days.rounded())
    }

    static func initialDifficulty(rating: Double) -> Double {
        clampDifficulty(w[4] - exp(w[5] * (rating - 1)) + 1)
    }

    static func nextDifficulty(_ difficulty: Double, rating: Double) -> Double {
        let delta = -w[6] * (rating - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        return clampDifficulty(w[7] * initialDifficulty(rating: 4) + (1 - w[7]) * damped)
    }

    private static func clampDifficulty(_ value: Double) -> Double {
        min(max(value, 1), 10)
    }
}
