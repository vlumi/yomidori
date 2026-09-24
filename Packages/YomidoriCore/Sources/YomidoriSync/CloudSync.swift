import CloudKit
import Foundation
import YomidoriCore

/// The cards, the collections with their covers and the lookup history kept in step across
/// the reader's devices through their own iCloud, by CloudKit's sync engine. The local files
/// stay the truth: this device's changes are sent as they are made, another device's are laid
/// over them, merged where both changed the same record before hearing of each other.
public final class CloudSync: CKSyncEngineDelegate, @unchecked Sendable {
    public struct Stores {
        public let cards: FileCardStore
        public let collections: FileCollectionStore
        public let lookups: FileLookupHistory
        /// Where a cover's file is, if it has one.
        public let coverURL: (UUID) -> URL?
        /// Takes a cover arrived with a collection into the cover files.
        public let saveCover: (UUID, URL) -> Void

        public init(
            cards: FileCardStore, collections: FileCollectionStore, lookups: FileLookupHistory,
            coverURL: @escaping (UUID) -> URL?, saveCover: @escaping (UUID, URL) -> Void
        ) {
            self.cards = cards
            self.collections = collections
            self.lookups = lookups
            self.coverURL = coverURL
            self.saveCover = saveCover
        }
    }

    public enum Status: Equatable, Sendable {
        case syncing
        case upToDate(Date)
        case failed(String)
    }

    /// Told of each change of status, from the engine's own threads.
    public var onStatus: (@Sendable (Status) -> Void)? {
        get { lock.withLock { statusHandler } }
        set { lock.withLock { statusHandler = newValue } }
    }
    private var statusHandler: (@Sendable (Status) -> Void)?

    let stores: Stores
    let zone = CKRecordZone(zoneName: "Yomidori")
    private let stateURL: URL
    private let fieldsURL: URL
    let lock = NSLock()
    /// Each record's system fields as the server last sent them, so a save is an update of
    /// that version and not a conflict with it.
    var systemFields: [String: Data]
    /// Read from whichever thread wrote a store, and let go of by `stop()`.
    private var engine: CKSyncEngine? {
        get { lock.withLock { currentEngine } }
        set { lock.withLock { currentEngine = newValue } }
    }
    private var currentEngine: CKSyncEngine?

    public init(containerIdentifier: String, stores: Stores, directory: URL) {
        self.stores = stores
        stateURL = directory.appendingPathComponent("sync-state.json")
        fieldsURL = directory.appendingPathComponent("sync-fields.json")
        systemFields =
            (try? Data(contentsOf: fieldsURL)).flatMap {
                try? JSONDecoder().decode([String: Data].self, from: $0)
            } ?? [:]
        let state = (try? Data(contentsOf: stateURL)).flatMap {
            try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0)
        }
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let engine = CKSyncEngine(
            CKSyncEngine.Configuration(
                database: database, stateSerialization: state, delegate: self))
        self.engine = engine
        if state == nil {
            engine.state.add(pendingDatabaseChanges: [.saveZone(zone)])
            sendEverything()
        }
    }

    /// Stops sending and fetching; the state is kept for when sync is turned on again.
    public func stop() async {
        let engine = lock.withLock { () -> CKSyncEngine? in
            defer { currentEngine = nil }
            return currentEngine
        }
        await engine?.cancelOperations()
    }

    /// Asks for what other devices did, as when the app comes to the front.
    public func fetch() async {
        try? await engine?.fetchChanges()
    }

    // MARK: Local changes

    public func recordsChanged(_ kind: SyncKind, _ change: RecordChange) {
        let saves = change.saved.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(id(SyncName(kind, $0)))
        }
        let deletes = change.deleted.map {
            CKSyncEngine.PendingRecordZoneChange.deleteRecord(id(SyncName(kind, $0)))
        }
        engine?.state.add(pendingRecordZoneChanges: saves + deletes)
    }

    public func historyCleared() {
        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(id(.historyCleared))])
    }

    /// What was changed while sync was off.
    public func send(_ unsent: UnsentChanges) {
        let zoneID = zone.zoneID
        engine?.state.add(
            pendingRecordZoneChanges: unsent.saved.map {
                .saveRecord(CKRecord.ID(recordName: $0, zoneID: zoneID))
            }
                + unsent.deleted.map {
                    .deleteRecord(CKRecord.ID(recordName: $0, zoneID: zoneID))
                })
    }

    /// Everything this device has, as when sync starts or the account changes.
    private func sendEverything() {
        recordsChanged(.card, RecordChange(saved: stores.cards.cards().map(\.id.uuidString)))
        recordsChanged(
            .collection, RecordChange(saved: stores.collections.collections().map(\.id.uuidString)))
        recordsChanged(.lookup, RecordChange(saved: stores.lookups.lookups().map(\.id)))
        if stores.lookups.clearedAt != nil { historyCleared() }
    }

    private func id(_ name: SyncName) -> CKRecord.ID {
        CKRecord.ID(recordName: name.recordName, zoneID: zone.zoneID)
    }

    // MARK: The engine

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            try? JSONEncoder().encode(update.stateSerialization).write(
                to: stateURL, options: .atomic)
        case .accountChange(let change):
            accountChanged(change.changeType, syncEngine)
        case .fetchedDatabaseChanges(let changes):
            if changes.deletions.contains(where: { $0.zoneID == zone.zoneID }) {
                // The zone was deleted from iCloud; this device's files are the truth, so it
                // puts them back.
                forgetSystemFields()
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(zone)])
                sendEverything()
            }
        case .fetchedRecordZoneChanges(let changes):
            apply(changes, syncEngine)
        case .sentRecordZoneChanges(let sent):
            handle(sent, syncEngine)
        case .willFetchChanges, .willSendChanges:
            onStatus?(.syncing)
        case .didFetchChanges, .didSendChanges:
            onStatus?(.upToDate(Date()))
        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter {
            context.options.scope.contains($0)
        }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            if let record = self.record(for: recordID) { return record }
            // Gone here since it was changed: nothing to send.
            syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
            return nil
        }
    }

    private func accountChanged(
        _ change: CKSyncEngine.Event.AccountChange.ChangeType, _ syncEngine: CKSyncEngine
    ) {
        switch change {
        case .signIn, .switchAccounts:
            forgetSystemFields()
            syncEngine.state.add(pendingDatabaseChanges: [.saveZone(zone)])
            sendEverything()
        case .signOut:
            // The cards stay on the device; they are sent again when an account is back.
            forgetSystemFields()
        @unknown default:
            break
        }
    }

    private func handle(
        _ sent: CKSyncEngine.Event.SentRecordZoneChanges, _ syncEngine: CKSyncEngine
    ) {
        sent.savedRecords.forEach(remember)
        for deleted in sent.deletedRecordIDs {
            lock.withLock { systemFields[deleted.recordName] = nil }
        }
        var retry: [CKSyncEngine.PendingRecordZoneChange] = []
        for failure in sent.failedRecordSaves {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                // Another device got there first: take its version into the local one, merged,
                // and send the merge on top of it.
                // One this version can't read (written by a newer one) is left as it is.
                guard let server = failure.error.serverRecord, mergeLocally(server) else {
                    syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    continue
                }
                remember(server)
                retry.append(.saveRecord(recordID))
            case .zoneNotFound:
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(zone)])
                retry.append(.saveRecord(recordID))
            case .unknownItem:
                lock.withLock { systemFields[recordID.recordName] = nil }
                retry.append(.saveRecord(recordID))
            case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited,
                .zoneBusy, .notAuthenticated, .quotaExceeded:
                // The engine tries these again itself.
                break
            default:
                onStatus?(.failed(failure.error.localizedDescription))
            }
        }
        saveSystemFields()
        if !retry.isEmpty { syncEngine.state.add(pendingRecordZoneChanges: retry) }
    }

    // MARK: System fields

    func remember(_ record: CKRecord) {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        lock.withLock { systemFields[record.recordID.recordName] = archiver.encodedData }
    }

    private func forgetSystemFields() {
        lock.withLock { systemFields = [:] }
        saveSystemFields()
    }

    func saveSystemFields() {
        let fields = lock.withLock { systemFields }
        try? JSONEncoder().encode(fields).write(to: fieldsURL, options: .atomic)
    }
}
