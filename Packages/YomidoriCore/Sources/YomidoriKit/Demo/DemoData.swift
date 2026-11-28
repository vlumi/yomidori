import CoreGraphics
import Foundation
import YomidoriCore
import YomidoriDictionary

/// The fixed cast, seeded into the demo's stores: some hundred cards from `DemoText`, spread
/// over the ranks the way a few months of reading would leave them, a shelf of names, words
/// kept from searches, collections with covers, and a lookup history. Dates are relative to
/// now, so the queue is in the same state at every launch, and every card has earned its
/// rank through answers at their due dates, so the ranks by day replay to it.
enum DemoData {
    static func seed(
        cards: FileCardStore, collections: FileCollectionStore, lookups: FileLookupHistory
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
        if let picture = DemoMode.picture, let still = Still(file: picture) {
            if let mode = DemoMode.mode { capture.mode = mode }
            capture.still = still
            return
        }
        if DemoMode.noPage, !DemoMode.spread { return }
        if DemoMode.spread { return seedSpread(capture) }
        // A text picked beforehand: on the demo's page where it stands there, else a page of
        // its own, so any phrase can be looked at. The reading takes the selection up when it
        // is done.
        var text = DemoText.page
        if let pick = DemoMode.pick, !pick.isEmpty {
            if let found = text.range(of: pick) {
                capture.selectedRange = CharacterRange.offsets(of: found, in: text)
            } else {
                text = pick
                capture.selectedRange = 0..<pick.count
            }
            // The drawer at half, so the picked word has room — unless asked for a height.
            if DemoMode.drawer == nil {
                DemoMode.defaults?.set(DrawerDetents.all[1], forKey: SettingsKey.readoutFraction)
            }
        }
        guard let image = DemoRenderer.verticalPage(text) else { return }
        let still = Still(image: image)
        if let mode = DemoMode.mode { capture.mode = mode }
        capture.still = still
        capture.transcript = text
        // Taken as read from its text, unless the recognizers are to have it.
        if !DemoMode.recognizes { capture.recognizedStillID = still.id }
    }

    /// Two pages, the cat's and then Melos's, as a spread — or, with no page asked, the first
    /// taken and the camera up for the second.
    @MainActor private static func seedSpread(_ capture: CaptureState) {
        let first = DemoText.cat.lines.joined(separator: "\n")
        let second = DemoText.melos.lines.joined(separator: "\n")
        guard let left = DemoRenderer.verticalPage(first),
            let right = DemoRenderer.verticalPage(second)
        else { return }
        capture.pages = [
            CaptureView.Page(
                still: Still(image: left), lines: [], analysis: nil, transcript: first)
        ]
        if DemoMode.noPage { return }
        let still = Still(image: right)
        capture.still = still
        capture.transcript = second
        capture.recognizedStillID = still.id
    }

}

/// Keeps the demo's cards and puts the reviewed ones at their ranks.
private struct CardSeeder {
    let store: FileCardStore
    let now: Date

    /// Where a card stands: the stability in days it has climbed to, when it is due, how
    /// many misses its log holds. Nil is a card still waiting for a lesson.
    struct Standing {
        let stability: Double
        let dueIn: Double
        var again = 0

        /// The days of answering at the due dates it takes to climb there, with room.
        var daysToClimb: Double { stability * 1.7 }
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
            let standing = Self.pattern[(index + phase * 5) % Self.pattern.count]
            // Kept long enough ago to have climbed where the pattern puts it.
            let daysAgo = max(
                Double(60 - phase * 12 - index).clamped(to: 1...120),
                standing?.daysToClimb ?? 0)
            guard
                var card = keep(
                    word.headword, word.reading, in: work.lines[word.line], collection: collection,
                    daysAgo: daysAgo), let standing
            else { continue }
            review(&card, standing, daysAgo: daysAgo)
            try? store.update(card)
        }
    }

    func keep(
        _ headword: String, _ reading: String, in sentence: String?, collection: Collection?,
        daysAgo: Double
    ) -> Card? {
        let offset = sentence.flatMap { text in
            text.range(of: headword).flatMap { CharacterRange.offsets(of: $0, in: text) }?
                .lowerBound
        }
        let sighting = Sighting(
            sentence: sentence ?? "", surface: headword, offset: offset ?? 0, source: nil,
            date: now.addingTimeInterval(-daysAgo * 86_400))
        return try? store.keep(
            sighting, headword: headword, reading: reading, entryID: nil, collection: collection?.id
        )
    }

    /// Started the day after it was kept and answered each time it came due, wrong the first
    /// `again` times, until it stood where the pattern puts it; then due when the pattern
    /// says, so the queue is the same at every launch. The log replays to the same ranks.
    private func review(_ card: inout Card, _ standing: Standing, daysAgo: Double) {
        let started = now.addingTimeInterval(-(daysAgo - 1) * 86_400)
        card.start(at: started)
        for question in Question.allCases {
            var date = started
            var step = 0
            while date < now {
                card.answer(
                    question, grade: step < standing.again ? .again : .good, at: date,
                    seconds: 6 + step * 4)
                step += 1
                guard let state = card.state(for: question),
                    state.stability < standing.stability
                else { break }
                date = state.due
            }
            if var state = card.state(for: question) {
                state.due = now.addingTimeInterval(standing.dueIn * 86_400)
                card.setState(state, for: question)
            }
        }
        if standing.stability > 100 { card.acceptedMeanings = ["(my own wording)"] }
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
