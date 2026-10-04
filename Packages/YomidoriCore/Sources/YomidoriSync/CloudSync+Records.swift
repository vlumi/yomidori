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
        }
    }

    /// The record's content as one JSON field; nil for a record not here.
    private func json<Record: Encodable>(_ record: Record?) -> [String: CKRecordValue]? {
        guard let record, let data = try? SyncPayload.encode(record) else { return nil }
        return ["json": data as NSData]
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
    }

    func apply(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges, _ syncEngine: CKSyncEngine) {
        var pendingSaves: Set<String> = []
        var pendingDeletes: Set<String> = []
        for change in syncEngine.state.pendingRecordZoneChanges {
            switch change {
            case .saveRecord(let id): pendingSaves.insert(id.recordName)
            case .deleteRecord(let id): pendingDeletes.insert(id.recordName)
            @unknown default: break
            }
        }
        var incoming = Incoming()
        // Remembered only once taken and kept, so a record this version can't read, or one
        // the store could not write, is not held as the server's version: the next save of
        // it then goes up without server fields, and the conflict that answers brings the
        // server's copy back down to merge.
        var taken: [SyncKind: [CKRecord]] = [:]
        for modification in changes.modifications {
            let record = modification.record
            // Deleted here and not yet sent: the delete goes out, the card doesn't come back.
            guard !pendingDeletes.contains(record.recordID.recordName) else { continue }
            if let kind = take(
                record, changedHere: pendingSaves.contains(record.recordID.recordName),
                into: &incoming)
            {
                taken[kind, default: []].append(record)
            }
        }
        var deleted: [SyncKind: Set<String>] = [:]
        for deletion in changes.deletions {
            lock.withLock { systemFields[deletion.recordID.recordName] = nil }
            let recordName = deletion.recordID.recordName
            // Changed here and not yet sent: the change wins, and goes out as a new record.
            guard !pendingSaves.contains(recordName) else { continue }
            if let kind = SyncName.kind(ofRecordName: recordName),
                let key = key(of: recordName, kind: kind)
            {
                deleted[kind, default: []].insert(key)
            }
        }
        keep(incoming, deleting: deleted, remembering: taken)
    }

    /// The records taken written to the stores, kind by kind, and remembered as the server's
    /// version only where the write took; a write that failed is said.
    private func keep(
        _ incoming: Incoming, deleting deleted: [SyncKind: Set<String>],
        remembering taken: [SyncKind: [CKRecord]]
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
        saveSystemFields()
        if let failure { onStatus?(.failed(failure.localizedDescription)) }
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
            guard let remote = decode(Card.self, record) else { return nil }
            let local = changedHere ? stores.cards.cards().first { $0.id == remote.id } : nil
            incoming.cards.append(local.map { $0.merged(with: remote) } ?? remote)
        case .collection:
            guard let collection = takeCollection(record, changedHere: changedHere) else {
                return nil
            }
            incoming.collections.append(collection)
        case .lookup:
            guard let remote = decode(Lookup.self, record) else { return nil }
            incoming.lookups.append(remote)
        case .historyCleared:
            incoming.clearedAt = SyncPayload.clearDate(record["cleared"] as? Date)
        case .settings:
            // The later change wins whichever device made it: no merge by hand.
            guard let remote = decode(StudySettings.self, record) else { return nil }
            incoming.settings = remote
        }
        return kind
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

    /// The server's version taken into the local one; false when it can't be read.
    func mergeLocally(_ server: CKRecord) -> Bool {
        guard let kind = SyncName.kind(ofRecordName: server.recordID.recordName) else {
            return false
        }
        switch kind {
        case .card:
            return mergeLocally(Card.self, server, stores.cards.card(id:)) { local, remote in
                try stores.cards.applyRemote(saving: [local.merged(with: remote)], deleting: [])
            }
        case .collection:
            return mergeLocally(Collection.self, server, collection(id:)) { local, remote in
                try stores.collections.applyRemote(
                    saving: [local.merged(with: remote)], deleting: [])
            }
        case .lookup:
            guard let remote = decode(Lookup.self, server) else { return false }
            let local = stores.lookups.lookups().first { $0.id == remote.id }
            try? stores.lookups.applyRemote(
                saving: [local.map { $0.merged(with: remote) } ?? remote], deleting: [],
                clearedAt: nil)
        case .historyCleared:
            try? stores.lookups.applyRemote(
                saving: [], deleting: [],
                clearedAt: SyncPayload.clearDate(server["cleared"] as? Date))
        case .settings:
            guard let remote = decode(StudySettings.self, server) else { return false }
            try? stores.settings.applyRemote(remote)
        }
        return true
    }

    /// A card's or a collection's server version merged into the local one, if there still
    /// is one: gone here since, the retried save finds nothing and is dropped.
    private func mergeLocally<Record: Decodable & Sanitizable & Identifiable>(
        _ type: Record.Type, _ server: CKRecord, _ local: (Record.ID) -> Record?,
        _ apply: (Record, Record) throws -> Void
    ) -> Bool {
        guard let remote = decode(type, server) else { return false }
        if let local = local(remote.id) { try? apply(local, remote) }
        return true
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
