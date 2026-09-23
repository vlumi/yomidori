import Foundation

extension Card {
    /// The last thing done to the card: a sighting or edit, an answer, a start.
    var lastTouched: Date {
        [modified, log.last?.date, started].compactMap { $0 }.max() ?? created
    }

    /// The same card changed on two devices before either heard of the other, as one: nothing
    /// done on either side is lost. Sightings, answers, accepted meanings and collections are
    /// the union; each question keeps the schedule of its later answer. Where the card
    /// stands (waiting, in review, shelved) comes from the side touched last, and a card
    /// sent back to waiting there keeps no schedule.
    public func merged(with other: Card) -> Card {
        let (newer, older) = other.lastTouched > lastTouched ? (other, self) : (self, other)
        let known = Set(newer.sightings.map(\.id))
        let sightings = newer.sightings + older.sightings.filter { !known.contains($0.id) }
        var log = newer.log
        for entry in older.log where !log.contains(entry) { log.append(entry) }
        log.sort { $0.date < $1.date }
        let waiting = newer.started == nil
        func later(_ question: Question) -> ReviewState? {
            if waiting { return nil }
            let states = [newer.state(for: question), older.state(for: question)].compactMap { $0 }
            return states.max { $0.lastReview < $1.lastReview }
        }
        return Card(
            id: id, headword: headword, reading: reading, entryID: newer.entryID ?? older.entryID,
            sightings: sightings.sorted { $0.date < $1.date },
            created: min(created, other.created), modified: max(modified, other.modified),
            review: later(.reading), meaningReview: later(.meaning), pitchReview: later(.pitch),
            log: log, acceptedMeanings: union(newer.acceptedMeanings, older.acceptedMeanings),
            started: newer.started, shelved: newer.shelved,
            collectionIDs: union(newer.collectionIDs, older.collectionIDs))
    }

    private func union<T: Equatable>(_ first: [T], _ second: [T]) -> [T] {
        first + second.filter { !first.contains($0) }
    }
}
