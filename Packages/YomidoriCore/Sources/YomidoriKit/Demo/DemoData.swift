import CoreGraphics
import Foundation
import YomidoriCore
import YomidoriDictionary

/// The fixed cast: two public-domain openings (漱石's 吾輩は猫である, 太宰's 走れメロス), cards
/// from them at every rank, a shelf, a search-kept word, collections with covers, and a
/// history. Dates are relative to now, so the queue is always in the same state.
enum DemoData {
    static let cat = [
        "吾輩は猫である。名前はまだ無い。", "どこで生れたかとんと見当がつかぬ。",
        "何でも薄暗いじめじめした所でニャーニャー泣いていた事だけは記憶している。",
        "吾輩はここで始めて人間というものを見た。",
    ]
    static let melos = [
        "メロスは激怒した。必ず、かの邪智暴虐の王を除かなければならぬと決意した。",
        "メロスには政治がわからぬ。メロスは、村の牧人である。", "笛を吹き、羊と遊んで暮して来た。",
    ]

    static var pageText: String { (cat + melos).joined(separator: "\n") }

    static func seed(
        cards: FileCardStore, collections: FileCollectionStore, lookups: FileLookupHistory
    ) {
        let shelves = seedCollections(into: collections)
        let seeder = CardSeeder(store: cards, now: Date())
        seeder.seedCat(in: shelves[0])
        seeder.seedMelos(in: shelves[1])
        _ = seeder.keep("牛丼", "ぎゅうどん", in: "牛丼 並盛 四百円", collection: shelves[2], daysAgo: 0.5)
        seedLookups(into: lookups)
    }

    /// The novel, the story and the street signs, the first two with covers.
    private static func seedCollections(into collections: FileCollectionStore) -> [Collection] {
        var shelves = [
            Collection(name: "吾輩は猫である", note: "夏目漱石", tags: ["book", "novel"]),
            Collection(name: "走れメロス", note: "太宰治", tags: ["novel"]),
            Collection(name: "看板", tags: ["street"]),
        ]
        let hues = [
            CGColor(red: 0.16, green: 0.36, blue: 0.30, alpha: 1),
            CGColor(red: 0.55, green: 0.22, blue: 0.16, alpha: 1),
        ]
        for (index, hue) in hues.enumerated() {
            if let image = DemoRenderer.cover(
                shelves[index].name, author: shelves[index].note, hue: hue),
                let id = try? StillArchive.save(Still(image: image))
            {
                shelves[index].coverID = id
            }
        }
        for shelf in shelves { try? collections.save(shelf) }
        return shelves
    }

    private static func seedLookups(into lookups: FileLookupHistory) {
        guard let dictionary = JMdict.bundled else { return }
        let words = [("猫", "ねこ"), ("名前", "なまえ"), ("笛", "ふえ"), ("並盛", "なみもり")]
        for (index, (headword, reading)) in words.enumerated() {
            guard let entry = dictionary.entry(headword: headword, reading: reading) else {
                continue
            }
            try? lookups.record(
                Lookup(
                    headword: headword, reading: reading, entryID: entry.id,
                    date: Date().addingTimeInterval(-Double(index) * 3_600),
                    source: index % 2 == 0 ? .page : .search))
        }
    }

    /// The page the Read tab opens on: the two openings as one vertical page, already read.
    @MainActor static func seed(_ capture: CaptureState) {
        guard let image = DemoRenderer.verticalPage(pageText) else { return }
        let still = Still(image: image)
        capture.still = still
        capture.transcript = pageText
        capture.recognizedStillID = still.id
    }
}

/// Keeps the demo's cards and puts the reviewed ones at their ranks.
private struct CardSeeder {
    let store: FileCardStore
    let now: Date

    func seedCat(in novel: Collection) {
        reviewed(
            "吾輩", "わがはい", in: DemoData.cat[0], novel, .init(daysAgo: 12, stability: 10, dueIn: 4))
        reviewed(
            "見当", "けんとう", in: DemoData.cat[1], novel,
            .init(daysAgo: 9, stability: 3, dueIn: -1, again: 1))
        _ = keep("薄暗い", "うすぐらい", in: DemoData.cat[2], collection: novel, daysAgo: 6)
        reviewed(
            "記憶", "きおく", in: DemoData.cat[2], novel, .init(daysAgo: 40, stability: 45, dueIn: 20))
        _ = keep("人間", "にんげん", in: DemoData.cat[3], collection: novel, daysAgo: 2)
    }

    func seedMelos(in story: Collection) {
        reviewed(
            "激怒", "げきど", in: DemoData.melos[0], story,
            .init(daysAgo: 200, stability: 200, dueIn: -2, accepted: ["rage"]))
        _ = keep("邪智暴虐", "じゃちぼうぎゃく", in: DemoData.melos[0], collection: story, daysAgo: 5)
        reviewed(
            "決意", "けつい", in: DemoData.melos[0], story, .init(daysAgo: 4, stability: 2, dueIn: -0.5))
        reviewed(
            "政治", "せいじ", in: DemoData.melos[1], story,
            .init(daysAgo: 400, stability: 400, dueIn: 90))
        _ = keep("牧人", "ぼくじん", in: DemoData.melos[1], collection: story, daysAgo: 3)
        _ = keep("羊", "ひつじ", in: nil, collection: story, daysAgo: 1)
        if var name = keep("メロス", "めろす", in: DemoData.melos[1], collection: story, daysAgo: 5) {
            name.shelve()
            try? store.update(name)
        }
    }

    func keep(
        _ headword: String, _ reading: String, in sentence: String?, collection: Collection,
        daysAgo: Double
    ) -> Card? {
        let offset = sentence.flatMap { text in
            text.range(of: headword).map { text.distance(from: text.startIndex, to: $0.lowerBound) }
        }
        let sighting = Sighting(
            sentence: sentence ?? "", surface: headword, offset: offset ?? 0, stillIDs: [],
            source: nil, date: now.addingTimeInterval(-daysAgo * 86_400))
        return try? store.keep(
            sighting, headword: headword, reading: reading, entryID: nil, collection: collection.id)
    }

    /// Where a reviewed card stands: both questions at `stability`, due in `dueIn` days, a
    /// log of answers with `again` misses among them.
    struct Standing {
        let daysAgo: Double
        let stability: Double
        let dueIn: Double
        var again = 0
        var accepted: [String] = []
    }

    private func reviewed(
        _ headword: String, _ reading: String, in sentence: String, _ collection: Collection,
        _ standing: Standing
    ) {
        let (stability, again, daysAgo) = (standing.stability, standing.again, standing.daysAgo)
        guard
            var card = keep(
                headword, reading, in: sentence, collection: collection, daysAgo: daysAgo)
        else { return }
        card.start(at: now.addingTimeInterval(-(daysAgo - 1) * 86_400))
        for question in [Question.reading, .meaning] {
            card.setState(
                ReviewState(
                    stability: stability, difficulty: 5,
                    due: now.addingTimeInterval(standing.dueIn * 86_400),
                    lastReview: now.addingTimeInterval(-max(1, stability) * 86_400),
                    reviews: 3 + again, lapses: again), for: question)
        }
        for step in 0..<(3 + again) {
            card.answer(
                step < again ? .reading : .meaning, grade: step < again ? .again : .good,
                at: now.addingTimeInterval(-Double(3 + again - step) * 86_400))
        }
        card.acceptedMeanings = standing.accepted
        try? store.update(card)
    }
}
