import Foundation

/// How many cards stood at each rank at the start of a day: the first look of the day is
/// kept, so the day's own reviewing shows on the next.
public struct RankSnapshot: Codable, Equatable, Sendable {
    /// The day's start.
    public let day: Date
    /// By `Rank.rawValue`.
    public let counts: [Int]

    public init(day: Date, counts: [Int]) {
        self.day = day
        self.counts = counts
    }

    public static func of(_ cards: [Card], day: Date) -> RankSnapshot {
        var counts = Array(repeating: 0, count: Rank.allCases.count)
        for card in cards { counts[card.rank.rawValue] += 1 }
        return RankSnapshot(day: day, counts: counts)
    }

    public func count(of rank: Rank) -> Int {
        counts.indices.contains(rank.rawValue) ? counts[rank.rawValue] : 0
    }

    public var total: Int { counts.reduce(0, +) }

    /// One snapshot a period, the first of each, for a chart over months; `.day` keeps all.
    public static func thinned(
        _ snapshots: [RankSnapshot], by component: Calendar.Component,
        calendar: Calendar = .current
    ) -> [RankSnapshot] {
        guard component != .day else { return snapshots }
        var seen: Set<Date> = []
        return snapshots.sorted { $0.day < $1.day }.filter { snapshot in
            let start =
                calendar.dateInterval(of: component, for: snapshot.day)?.start ?? snapshot.day
            return seen.insert(start).inserted
        }
    }
}

/// The snapshots in one JSON file beside the stores, this device's own: every device sees
/// the same cards, so each takes the same snapshot.
public final class FileRankSnapshots: @unchecked Sendable {
    let file: RecordFile<RankSnapshot>

    public init(url: URL) {
        file = RecordFile(
            url: url, label: "fi.misaki.yomidori.snapshots",
            key: { String($0.day.timeIntervalSince1970) })
    }

    public func snapshots() -> [RankSnapshot] {
        file.records().sorted { $0.day < $1.day }
    }

    /// Keeps today's snapshot if there is none yet; true when one was taken.
    @discardableResult
    public func take(of cards: [Card], at date: Date, calendar: Calendar = .current) throws
        -> Bool
    {
        let day = calendar.startOfDay(for: date)
        return try file.write { snapshots in
            guard !snapshots.contains(where: { $0.day == day }) else { return false }
            snapshots.append(RankSnapshot.of(cards, day: day))
            return true
        }
    }

    /// The whole history at once, as the demo seeds it.
    public func replaceAll(_ snapshots: [RankSnapshot]) throws {
        try file.write { $0 = snapshots }
    }
}
