import CloudKit
import Foundation
import YomidoriCore

extension CloudSync {
    // MARK: Records out

    func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let kind = SyncName.kind(ofRecordName: recordID.recordName),
            let key = key(of: recordID.recordName, kind: kind)
        else { return nil }
        let record = blankRecord(recordID, type: kind.recordType)
        switch kind {
        case .card:
            guard let id = UUID(uuidString: key),
                let card = stores.cards.cards().first(where: { $0.id == id }),
                let data = try? SyncPayload.encode(card)
            else { return nil }
            record["json"] = data
        case .collection:
            guard let id = UUID(uuidString: key),
                let collection = stores.collections.collections().first(where: { $0.id == id }),
                let data = try? SyncPayload.encode(collection)
            else { return nil }
            record["json"] = data
            record["cover"] = collection.coverID.flatMap(stores.coverURL).map(
                CKAsset.init(fileURL:))
        case .lookup:
            guard let lookup = stores.lookups.lookups().first(where: { $0.id == key }),
                let data = try? SyncPayload.encode(lookup)
            else { return nil }
            record["json"] = data
        case .historyCleared:
            guard let cleared = stores.lookups.clearedAt else { return nil }
            record["cleared"] = cleared
        }
        return record
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
    }

    func apply(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges, _ syncEngine: CKSyncEngine) {
        let pending = Set(
            syncEngine.state.pendingRecordZoneChanges.compactMap { change -> String? in
                if case .saveRecord(let id) = change { return id.recordName }
                return nil
            })
        var incoming = Incoming()
        for modification in changes.modifications {
            let record = modification.record
            remember(record)
            take(record, changedHere: pending.contains(record.recordID.recordName), into: &incoming)
        }
        var deleted: [SyncKind: Set<String>] = [:]
        for deletion in changes.deletions {
            lock.withLock { systemFields[deletion.recordID.recordName] = nil }
            let recordName = deletion.recordID.recordName
            if let kind = SyncName.kind(ofRecordName: recordName),
                let key = key(of: recordName, kind: kind)
            {
                deleted[kind, default: []].insert(key)
            }
        }
        saveSystemFields()
        try? stores.cards.applyRemote(
            saving: incoming.cards, deleting: Set((deleted[.card] ?? []).compactMap(UUID.init)))
        try? stores.collections.applyRemote(
            saving: incoming.collections,
            deleting: Set((deleted[.collection] ?? []).compactMap(UUID.init)))
        let local = Dictionary(
            stores.lookups.lookups().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        try? stores.lookups.applyRemote(
            saving: incoming.lookups.map { remote in
                local[remote.id].map { $0.merged(with: remote) } ?? remote
            },
            deleting: deleted[.lookup] ?? [], clearedAt: incoming.clearedAt)
    }

    /// One record from another device; merged with the local one only where this device has
    /// changed it too and not yet sent the change.
    private func take(_ record: CKRecord, changedHere: Bool, into incoming: inout Incoming) {
        guard let kind = SyncName.kind(ofRecordName: record.recordID.recordName) else { return }
        switch kind {
        case .card:
            guard let remote = decode(Card.self, record) else { return }
            let local = changedHere ? stores.cards.cards().first { $0.id == remote.id } : nil
            incoming.cards.append(local.map { $0.merged(with: remote) } ?? remote)
        case .collection:
            guard let remote = decode(Collection.self, record) else { return }
            if let coverID = remote.coverID, let url = (record["cover"] as? CKAsset)?.fileURL {
                stores.saveCover(coverID, url)
            }
            let local =
                changedHere ? stores.collections.collections().first { $0.id == remote.id } : nil
            incoming.collections.append(local.map { $0.merged(with: remote) } ?? remote)
        case .lookup:
            if let remote = decode(Lookup.self, record) { incoming.lookups.append(remote) }
        case .historyCleared:
            incoming.clearedAt = SyncPayload.clearDate(record["cleared"] as? Date)
        }
    }

    func mergeLocally(_ server: CKRecord) {
        guard let kind = SyncName.kind(ofRecordName: server.recordID.recordName) else { return }
        switch kind {
        case .card:
            guard let remote = decode(Card.self, server),
                let local = stores.cards.cards().first(where: { $0.id == remote.id })
            else { return }
            try? stores.cards.applyRemote(saving: [local.merged(with: remote)], deleting: [])
        case .collection:
            guard let remote = decode(Collection.self, server),
                let local = stores.collections.collections().first(where: { $0.id == remote.id })
            else { return }
            try? stores.collections.applyRemote(saving: [local.merged(with: remote)], deleting: [])
        case .lookup:
            guard let remote = decode(Lookup.self, server) else { return }
            let local = stores.lookups.lookups().first { $0.id == remote.id }
            try? stores.lookups.applyRemote(
                saving: [local.map { $0.merged(with: remote) } ?? remote], deleting: [],
                clearedAt: nil)
        case .historyCleared:
            try? stores.lookups.applyRemote(
                saving: [], deleting: [],
                clearedAt: SyncPayload.clearDate(server["cleared"] as? Date))
        }
    }

    private func decode<Record: Decodable & Sanitizable>(_ type: Record.Type, _ record: CKRecord)
        -> Record?
    {
        (record["json"] as? Data).flatMap { SyncPayload.intake(type, from: $0) }
    }
}
