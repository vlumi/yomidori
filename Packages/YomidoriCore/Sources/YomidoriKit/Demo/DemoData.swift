import CoreGraphics
import Foundation
import YomidoriCore
import YomidoriDictionary

/// The fixed cast, seeded into the demo's stores: some hundred cards from `DemoText`, spread
/// over the ranks the way a few months of reading would leave them, a shelf of names, words
/// kept from searches, collections with covers, and a lookup history. Dates are relative to
/// now, so the queue is in the same state at every launch.
enum DemoData {
    static func seed(
        cards: FileCardStore, collections: FileCollectionStore, lookups: FileLookupHistory,
        snapshots: FileRankSnapshots
    ) {
        let seeder = CardSeeder(store: cards, now: Date())
        for (index, work) in (DemoText.works + [DemoText.sign]).enumerated() {
            let collection = seedCollection(for: work, cover: index < 2, into: collections)
            seeder.seed(work, in: collection, phase: index)
        }
        let story = collections.collections()[1]
        for (headword, reading) in DemoText.searched {
            _ = seeder.keep(headword, reading, in: nil, collection: nil, daysAgo: 1)
        }
        for (headword, reading) in DemoText.names {
            if var name = seeder.keep(headword, reading, in: nil, collection: story, daysAgo: 20) {
                name.shelve()
                try? cards.update(name)
            }
        }
        seedLookups(into: lookups)
        seedSnapshots(into: snapshots, ending: cards.cards())
    }

    /// Six weeks of ranks up to yesterday, walked back from the cards as they stand: fewer
    /// cards the further back, and the higher a rank the faster it thins. Today's is taken
    /// from the cards as on any day.
    private static func seedSnapshots(into snapshots: FileRankSnapshots, ending cards: [Card]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let final = RankSnapshot.of(cards, day: today).counts
        let history = (1...42).reversed().compactMap { daysAgo -> RankSnapshot? in
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }
            let back = Double(daysAgo) / 42
            var counts = Rank.allCases.map { rank -> Int in
                let thinning = rank == .nest ? 0.3 : 0.4 + 0.12 * Double(rank.rawValue)
                return Int((Double(final[rank.rawValue]) * max(0, 1 - back * thinning)).rounded())
            }
            // The eggs make up the total, which grows as pages are read.
            let total = Int((Double(final.reduce(0, +)) * (1 - back * 0.6)).rounded())
            let others = counts.enumerated().filter { $0.offset != Rank.egg.rawValue }
                .map(\.element).reduce(0, +)
            counts[Rank.egg.rawValue] = max(0, total - others)
            return RankSnapshot(day: day, counts: counts)
        }
        try? snapshots.replaceAll(history)
    }

    private static func seedCollection(
        for work: DemoText.Work, cover: Bool, into collections: FileCollectionStore
    ) -> Collection {
        var collection = Collection(name: work.title, note: work.author, tags: work.tags)
        let hues = [
            CGColor(red: 0.16, green: 0.36, blue: 0.30, alpha: 1),
            CGColor(red: 0.55, green: 0.22, blue: 0.16, alpha: 1),
        ]
        if cover,
            let image = DemoRenderer.cover(
                work.title, author: work.author, hue: hues[collections.collections().count % 2]),
            let id = try? CoverArchive.save(image)
        {
            collection.coverID = id
        }
        try? collections.save(collection)
        return collection
    }

    private static func seedLookups(into lookups: FileLookupHistory) {
        guard let dictionary = JMdict.bundled else { return }
        let words = DemoText.searched + [("名前", "なまえ"), ("笛", "ふえ"), ("黒板", "こくばん")]
        for (index, (headword, reading)) in words.enumerated() {
            guard let entry = dictionary.entry(headword: headword, reading: reading) else {
                continue
            }
            try? lookups.record(
                Lookup(
                    headword: headword, reading: reading, entryID: entry.id,
                    date: Date().addingTimeInterval(-Double(index) * 5_400),
                    source: index % 3 == 0 ? .search : .page))
        }
    }

    /// The page the Read tab opens on, already read.
    @MainActor static func seed(_ capture: CaptureState) {
        guard let image = DemoRenderer.verticalPage(DemoText.page) else { return }
        let still = Still(image: image)
        capture.still = still
        capture.transcript = DemoText.page
        capture.recognizedStillID = still.id
    }
}

/// Keeps the demo's cards and puts the reviewed ones at their ranks.
private struct CardSeeder {
    let store: FileCardStore
    let now: Date

    /// Where a card stands: the reading's stability in days, when it is due, how many misses
    /// its log holds. Nil is a card still waiting for a lesson.
    struct Standing {
        let stability: Double
        let dueIn: Double
        var again = 0
    }

    /// A few months of reading: most cards young, a few settled, one in four still waiting,
    /// one in seven due today. Cycled by the word's place, so every launch is the same.
    private static let pattern: [Standing?] = [
        Standing(stability: 3, dueIn: 2), nil, Standing(stability: 12, dueIn: 5),
        Standing(stability: 0.8, dueIn: -1, again: 1), Standing(stability: 45, dueIn: 30), nil,
        Standing(stability: 5, dueIn: 1), Standing(stability: 20, dueIn: 3), nil,
        Standing(stability: 150, dueIn: 60), Standing(stability: 2, dueIn: 1),
        Standing(stability: 9, dueIn: 4),
        nil, Standing(stability: 400, dueIn: 200), Standing(stability: 4, dueIn: -1, again: 2),
        Standing(stability: 60, dueIn: 25), nil, Standing(stability: 1.5, dueIn: 1),
        Standing(stability: 25, dueIn: 10), Standing(stability: 250, dueIn: -2), nil,
    ]

    /// The work's words as cards in its collection; `phase` shifts the pattern so the works
    /// differ, and later works are newer.
    func seed(_ work: DemoText.Work, in collection: Collection, phase: Int) {
        for (index, word) in work.words.enumerated() {
            let daysAgo = Double(60 - phase * 12 - index).clamped(to: 1...120)
            guard
                var card = keep(
                    word.headword, word.reading, in: work.lines[word.line], collection: collection,
                    daysAgo: daysAgo)
            else { continue }
            guard let standing = Self.pattern[(index + phase * 5) % Self.pattern.count] else {
                continue
            }
            review(&card, standing, daysAgo: daysAgo)
            try? store.update(card)
        }
    }

    func keep(
        _ headword: String, _ reading: String, in sentence: String?, collection: Collection?,
        daysAgo: Double
    ) -> Card? {
        let offset = sentence.flatMap { text in
            text.range(of: headword).map { text.distance(from: text.startIndex, to: $0.lowerBound) }
        }
        let sighting = Sighting(
            sentence: sentence ?? "", surface: headword, offset: offset ?? 0, source: nil,
            date: now.addingTimeInterval(-daysAgo * 86_400))
        return try? store.keep(
            sighting, headword: headword, reading: reading, entryID: nil, collection: collection?.id
        )
    }

    private func review(_ card: inout Card, _ standing: Standing, daysAgo: Double) {
        card.start(at: now.addingTimeInterval(-(daysAgo - 1) * 86_400))
        for question in Question.allCases {
            card.setState(
                ReviewState(
                    stability: standing.stability, difficulty: 5,
                    due: now.addingTimeInterval(standing.dueIn * 86_400),
                    lastReview: now.addingTimeInterval(
                        -min(daysAgo - 1, standing.stability) * 86_400),
                    reviews: 3 + standing.again, lapses: standing.again), for: question)
        }
        for step in 0..<(3 + standing.again) {
            card.answer(
                step < standing.again ? .reading : .meaning,
                grade: step < standing.again ? .again : .good,
                at: now.addingTimeInterval(-Double(3 + standing.again - step) * 86_400),
                seconds: 6 + step * 4)
        }
        if standing.stability > 100 { card.acceptedMeanings = ["(my own wording)"] }
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
