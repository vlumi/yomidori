import CloudKit
import Foundation
import YomidoriCore

extension CloudSync {
    // MARK: Records out

    func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let kind = SyncName.kind(ofRecordName: recordID.recordName),
            let key = key(of: recordID.recordName, kind: kind),
            let fields = fields(of: kind, key: key)
        else { return nil }
        let record = blankRecord(recordID, type: kind.recordType)
        for (name, value) in fields { record[name] = value }
        return record
    }

    /// A record's fields from the stores; nil when this device no longer has it.
    private func fields(of kind: SyncKind, key: String) -> [String: CKRecordValue]? {
        switch kind {
        case .card:
            return json(UUID(uuidString: key).flatMap { id in stores.cards.card(id: id) })
        case .collection:
            guard let id = UUID(uuidString: key),
                let collection = stores.collections.collections().first(where: { $0.id == id }),
                var fields = json(collection)
            else { return nil }
            fields["cover"] = collection.coverID.flatMap(stores.coverURL).map(
                CKAsset.init(fileURL:))
            return fields
        case .lookup:
            return json(stores.lookups.lookups().first { $0.id == key })
        case .historyCleared:
            return stores.lookups.clearedAt.map { ["cleared": $0 as NSDate] }
        case .settings:
            return json(stores.settings.settings())
        case .erased:
            return stores.erased.date.map { ["erased": $0 as NSDate] }
        }
    }

    /// The record's content as one JSON field, stamped with the era it goes under; nil for a
    /// record not here.
    private func json<Record: Encodable>(_ record: Record?) -> [String: CKRecordValue]? {
        guard let record, let data = try? SyncPayload.encode(record, era: stores.erased.date)
        else { return nil }
        return ["json": data as NSData]
    }

    /// The era a card, collection or lookup record was sent under; nil for the other kinds,
    /// which no erase touches.
    private func era(of record: CKRecord) -> Date? {
        (record["json"] as? Data).flatMap(SyncPayload.era(of:))
    }

    /// The store key a record name stands for; a lookup's name may be a hash, found among the
    /// lookups this device has.
    private func key(of recordName: String, kind: SyncKind) -> String? {
        SyncName.key(
            ofRecordName: recordName,
            among: kind == .lookup ? stores.lookups.lookups().map(\.id) : [])
    }

    private func blankRecord(_ recordID: CKRecord.ID, type: String) -> CKRecord {
        let fields = lock.withLock { systemFields[recordID.recordName] }
        if let fields, let coder = try? NSKeyedUnarchiver(forReadingFrom: fields),
            let record = CKRecord(coder: coder)
        {
            coder.finishDecoding()
            return record
        }
        return CKRecord(recordType: type, recordID: recordID)
    }

    // MARK: Records in

    private struct Incoming {
        var cards: [Card] = []
        var collections: [Collection] = []
        var lookups: [Lookup] = []
        var clearedAt: Date?
        var settings: StudySettings?
        var erasedAt: Date?
        /// Sent by a device that had not heard of the erase: the past, answered once the
        /// batch is kept.
        var stale: [CKRecord] = []
    }

    func apply(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges, _ syncEngine: CKSyncEngine) {
        let (pendingSaves, pendingDeletes) = pending(syncEngine)
        var incoming = Incoming()
        // Remembered only once taken and kept, so a record this version can't read, or one
        // the store could not write, is not held as the server's version: the next save of
        // it then goes up without server fields, and the conflict that answers brings the
        // server's copy back down to merge.
        var taken = eraseAhead(of: changes.modifications.map(\.record), into: &incoming)
        let mark = [stores.erased.date, incoming.erasedAt].compactMap { $0 }.max()
        // Everything held is about to go: nothing of it is merged into what came.
        let erasing = Erase.isAhead(era: incoming.erasedAt, mark: stores.erased.date)
        for modification in changes.modifications {
            let record = modification.record
            let name = record.recordID.recordName
            guard let kind = SyncName.kind(ofRecordName: name), kind != .erased,
                // Deleted here and not yet sent: the delete goes out, the card doesn't come
                // back.
                !pendingDeletes.contains(name)
            else { continue }
            if SyncKind.erasable.contains(kind), Erase.isStale(era: era(of: record), mark: mark) {
                incoming.stale.append(record)
                continue
            }
            if let kind = take(
                record, changedHere: !erasing && pendingSaves.contains(name), into: &incoming)
            {
                taken[kind, default: []].append(record)
            }
        }
        let deleted = forgotten(in: changes, pendingSaves: pendingSaves)
        keep(incoming, deleting: deleted, remembering: taken, syncEngine)
    }

    /// What this device has changed or deleted and not yet sent, by record name.
    private func pending(_ syncEngine: CKSyncEngine) -> (saves: Set<String>, deletes: Set<String>) {
        var saves: Set<String> = []
        var deletes: Set<String> = []
        for change in syncEngine.state.pendingRecordZoneChanges {
            switch change {
            case .saveRecord(let id): saves.insert(id.recordName)
            case .deleteRecord(let id): deletes.insert(id.recordName)
            @unknown default: break
            }
        }
        return (saves, deletes)
    }

    /// An erase first, if one came: the rest of the batch is read against it. The erase
    /// records, to remember once kept.
    private func eraseAhead(of records: [CKRecord], into incoming: inout Incoming)
        -> [SyncKind: [CKRecord]]
    {
        var taken: [SyncKind: [CKRecord]] = [:]
        for record in records
        where SyncName.kind(ofRecordName: record.recordID.recordName) == .erased {
            incoming.erasedAt = SyncPayload.clearDate(record["erased"] as? Date)
            taken[.erased, default: []].append(record)
        }
        return taken
    }

    /// The deletions to lay onto the stores, by kind and key; one of a record changed here
    /// and not yet sent is passed over, since the change wins and goes out as a new record.
    private func forgotten(
        in changes: CKSyncEngine.Event.FetchedRecordZoneChanges, pendingSaves: Set<String>
    ) -> [SyncKind: Set<String>] {
        var deleted: [SyncKind: Set<String>] = [:]
        for deletion in changes.deletions {
            lock.withLock { systemFields[deletion.recordID.recordName] = nil }
            let recordName = deletion.recordID.recordName
            guard !pendingSaves.contains(recordName) else { continue }
            if let kind = SyncName.kind(ofRecordName: recordName),
                let key = key(of: recordName, kind: kind)
            {
                deleted[kind, default: []].insert(key)
            }
        }
        return deleted
    }

    /// The records taken written to the stores, kind by kind, and remembered as the server's
    /// version only where the write took; a write that failed is said. An erase goes first,
    /// so what came with it is laid onto nothing.
    private func keep(
        _ incoming: Incoming, deleting deleted: [SyncKind: Set<String>],
        remembering taken: [SyncKind: [CKRecord]], _ syncEngine: CKSyncEngine
    ) {
        var failure: Error?
        func kept(_ kinds: [SyncKind], _ apply: () throws -> Void) {
            do {
                try apply()
                for kind in kinds { taken[kind]?.forEach(remember) }
            } catch {
                failure = error
            }
        }
        if let erasedAt = incoming.erasedAt {
            kept([.erased]) { try takeErase(erasedAt) }
        }
        kept([.card]) {
            try stores.cards.applyRemote(
                saving: incoming.cards,
                deleting: Set((deleted[.card] ?? []).compactMap(UUID.init)))
        }
        kept([.collection]) {
            try stores.collections.applyRemote(
                saving: incoming.collections,
                deleting: Set((deleted[.collection] ?? []).compactMap(UUID.init)))
        }
        kept([.lookup, .historyCleared]) {
            let local = Dictionary(
                stores.lookups.lookups().map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first })
            try stores.lookups.applyRemote(
                saving: incoming.lookups.map { remote in
                    local[remote.id].map { $0.merged(with: remote) } ?? remote
                },
                deleting: deleted[.lookup] ?? [], clearedAt: incoming.clearedAt)
        }
        if let settings = incoming.settings {
            kept([.settings]) { try stores.settings.applyRemote(settings) }
        }
        answer(incoming.stale, syncEngine)
        saveSystemFields()
        if let failure { failed(failure.localizedDescription) } else { succeeded() }
    }

    /// Another device's erase, newer than any known here: everything goes, the covers and
    /// the ranks by day with it.
    private func takeErase(_ date: Date) throws {
        if try Erase.applyRemote(stores.eraseStores, at: date) { stores.clearDeviceFiles() }
    }

    /// Records sent by a device that had not heard of the erase, answered with this device's
    /// word on each: its own copy, sent over the stale one, or a delete where it has none.
    /// The sender erases itself once it fetches.
    private func answer(_ stale: [CKRecord], _ syncEngine: CKSyncEngine) {
        for record in stale {
            remember(record)
            let recordID = record.recordID
            syncEngine.state.add(pendingRecordZoneChanges: [
                self.record(for: recordID) != nil ? .saveRecord(recordID) : .deleteRecord(recordID)
            ])
        }
    }

    /// One record from another device; merged with the local one only where this device has
    /// changed it too and not yet sent the change. Its kind when taken, nil when it can't be
    /// read.
    @discardableResult
    private func take(_ record: CKRecord, changedHere: Bool, into incoming: inout Incoming)
        -> SyncKind?
    {
        guard let kind = SyncName.kind(ofRecordName: record.recordID.recordName) else {
            return nil
        }
        switch kind {
        case .card:
            guard let card = takeCard(record, changedHere: changedHere) else { return nil }
            incoming.cards.append(card)
        case .collection:
            guard let collection = takeCollection(record, changedHere: changedHere) else {
                return nil
            }
            incoming.collections.append(collection)
        case .lookup:
            guard let remote = decode(Lookup.self, record) else { return nil }
            incoming.lookups.append(remote)
        case .historyCleared, .settings, .erased:
            return takeMark(kind, record, into: &incoming)
        }
        return kind
    }

    /// The records that are not a card, a collection or a lookup: the history's clear, the
    /// study settings, and the erase, which `apply` read ahead of the batch.
    private func takeMark(_ kind: SyncKind, _ record: CKRecord, into incoming: inout Incoming)
        -> SyncKind?
    {
        switch kind {
        case .historyCleared:
            incoming.clearedAt = SyncPayload.clearDate(record["cleared"] as? Date)
        case .settings:
            // The later change wins whichever device made it: no merge by hand.
            guard let remote = decode(StudySettings.self, record) else { return nil }
            incoming.settings = remote
        case .erased:
            return nil
        case .card, .collection, .lookup:
            return nil
        }
        return kind
    }

    private func takeCard(_ record: CKRecord, changedHere: Bool) -> Card? {
        guard let remote = decode(Card.self, record) else { return nil }
        let local = changedHere ? stores.cards.card(id: remote.id) : nil
        return local.map { $0.merged(with: remote) } ?? remote
    }

    /// A collection from another device, its cover taken into the cover files first.
    private func takeCollection(_ record: CKRecord, changedHere: Bool) -> Collection? {
        guard let remote = decode(Collection.self, record) else { return nil }
        if let coverID = remote.coverID, let url = (record["cover"] as? CKAsset)?.fileURL {
            stores.saveCover(coverID, url)
        }
        let local =
            changedHere ? stores.collections.collections().first { $0.id == remote.id } : nil
        return local.map { $0.merged(with: remote) } ?? remote
    }

    /// What a save that found a newer version on the server comes to.
    enum ConflictOutcome {
        /// The server's version taken into the local one; the result goes up on top of it.
        case sendAgain
        /// The server's version stands; nothing more to send.
        case settled
        /// The server's version can't be read (written by a newer build): left as it is.
        case unreadable
    }

    /// The server's version taken into the local one.
    func mergeLocally(_ server: CKRecord) -> ConflictOutcome {
        guard let kind = SyncName.kind(ofRecordName: server.recordID.recordName) else {
            return .unreadable
        }
        switch kind {
        case .card:
            return resolve(Card.self, server, stores.cards.card(id:), { $0.merged(with: $1) }) {
                try stores.cards.applyRemote(saving: $0, deleting: [])
            }
        case .collection:
            return resolve(Collection.self, server, collection(id:), { $0.merged(with: $1) }) {
                try stores.collections.applyRemote(saving: $0, deleting: [])
            }
        case .lookup:
            return resolve(Lookup.self, server, lookup(id:), { $0.merged(with: $1) }) {
                try stores.lookups.applyRemote(saving: $0, deleting: [], clearedAt: nil)
            }
        case .historyCleared:
            try? stores.lookups.applyRemote(
                saving: [], deleting: [],
                clearedAt: SyncPayload.clearDate(server["cleared"] as? Date))
        case .erased:
            if let date = SyncPayload.clearDate(server["erased"] as? Date) {
                try? takeErase(date)
            }
        case .settings:
            guard let remote = decode(StudySettings.self, server) else { return .unreadable }
            try? stores.settings.applyRemote(remote)
        }
        return .sendAgain
    }

    /// The server's version of a card, a collection or a lookup against this device's.
    /// Merged where both are of the same era and this device still has it (gone here since,
    /// the retried save finds nothing and is dropped); written over where sent by a device
    /// that had not heard of the erase; taken whole where from past an erase not fetched here
    /// yet, this device's copy going with everything else when the erase arrives.
    private func resolve<Record: Decodable & Sanitizable & Identifiable>(
        _ type: Record.Type, _ server: CKRecord, _ local: (Record.ID) -> Record?,
        _ merge: (Record, Record) -> Record, _ save: ([Record]) throws -> Void
    ) -> ConflictOutcome {
        let era = era(of: server)
        let mark = stores.erased.date
        if Erase.isStale(era: era, mark: mark) { return .sendAgain }
        guard let remote = decode(type, server) else { return .unreadable }
        if Erase.isAhead(era: era, mark: mark) {
            try? save([remote])
            return .settled
        }
        if let local = local(remote.id) { try? save([merge(local, remote)]) }
        return .sendAgain
    }

    private func lookup(id: String) -> Lookup? {
        stores.lookups.lookups().first { $0.id == id }
    }

    private func collection(id: UUID) -> Collection? {
        stores.collections.collections().first { $0.id == id }
    }

    private func decode<Record: Decodable & Sanitizable>(_ type: Record.Type, _ record: CKRecord)
        -> Record?
    {
        (record["json"] as? Data).flatMap { SyncPayload.intake(type, from: $0) }
    }
}
