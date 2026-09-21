import Foundation

/// FSRS's Again (1) and Good (3).
public enum Grade: String, Codable, Sendable {
    case again
    case good

    var rating: Double {
        self == .again ? 1 : 3
    }
}

/// Stability is the days until recall drops to 90 %, difficulty 1 to 10; no state means
/// never reviewed and due at once.
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

/// FSRS-5 with its published default parameters and a desired retention of 90 %.
public enum FSRS {
    public static let desiredRetention = 0.9
    static let decay = -0.5
    static let factor = 19.0 / 81.0
    static let day: TimeInterval = 86_400
    static let weights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
        1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
    ]

    public static func retrievability(of state: ReviewState, at date: Date) -> Double {
        let elapsed = max(0, date.timeIntervalSince(state.lastReview) / day)
        return pow(1 + factor * elapsed / state.stability, decay)
    }

    public static func review(_ state: ReviewState?, grade: Grade, at date: Date) -> ReviewState {
        let rating = grade.rating
        var next: ReviewState
        if let state {
            let elapsedDays = date.timeIntervalSince(state.lastReview) / day
            let retrievability = retrievability(of: state, at: date)
            let stability: Double
            if elapsedDays < 1 {
                stability = state.stability * exp(weights[17] * (rating - 3 + weights[18]))
            } else if grade == .again {
                stability = min(
                    weights[11] * pow(state.difficulty, -weights[12])
                        * (pow(state.stability + 1, weights[13]) - 1)
                        * exp(weights[14] * (1 - retrievability)),
                    state.stability)
            } else {
                stability =
                    state.stability
                    * (exp(weights[8]) * (11 - state.difficulty) * pow(state.stability, -weights[9])
                        * (exp(weights[10] * (1 - retrievability)) - 1) + 1)
            }
            next = state
            next.stability = max(stability, 0.01)
            next.difficulty = nextDifficulty(state.difficulty, rating: rating)
            next.reviews += 1
            if grade == .again { next.lapses += 1 }
        } else {
            next = ReviewState(
                stability: weights[Int(rating) - 1], difficulty: initialDifficulty(rating: rating),
                due: date,
                lastReview: date, reviews: 1, lapses: grade == .again ? 1 : 0)
        }
        next.lastReview = date
        next.due = date.addingTimeInterval(interval(forStability: next.stability) * day)
        return next
    }

    /// Whole days, one at least.
    static func interval(forStability stability: Double) -> Double {
        let days = stability / factor * (pow(desiredRetention, 1 / decay) - 1)
        return max(1, days.rounded())
    }

    static func initialDifficulty(rating: Double) -> Double {
        clampDifficulty(weights[4] - exp(weights[5] * (rating - 1)) + 1)
    }

    static func nextDifficulty(_ difficulty: Double, rating: Double) -> Double {
        let delta = -weights[6] * (rating - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        return clampDifficulty(
            weights[7] * initialDifficulty(rating: 4) + (1 - weights[7]) * damped)
    }

    private static func clampDifficulty(_ value: Double) -> Double {
        min(max(value, 1), 10)
    }
}
