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
        public let settings: FileStudySettings
        /// Where a cover's file is, if it has one.
        public let coverURL: (UUID) -> URL?
        /// Takes a cover arrived with a collection into the cover files.
        public let saveCover: (UUID, URL) -> Void

        public init(
            cards: FileCardStore, collections: FileCollectionStore, lookups: FileLookupHistory,
            settings: FileStudySettings, coverURL: @escaping (UUID) -> URL?,
            saveCover: @escaping (UUID, URL) -> Void
        ) {
            self.cards = cards
            self.collections = collections
            self.lookups = lookups
            self.settings = settings
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
    /// A save or a write failed in the last batch: "up to date" must not say otherwise
    /// until a batch goes through whole. Under `lock`.
    private var batchFailed = false
    /// Saves held back for a better moment — iCloud full — and tried again on the next fetch.
    /// Under `lock`.
    private var heldBack: [CKSyncEngine.PendingRecordZoneChange] = []
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

    /// Asks for what other devices did, as when the app comes to the front; what was held
    /// back goes up again with it.
    public func fetch() async {
        let retry = lock.withLock { () -> [CKSyncEngine.PendingRecordZoneChange] in
            defer { heldBack = [] }
            return heldBack
        }
        if !retry.isEmpty { engine?.state.add(pendingRecordZoneChanges: retry) }
        try? await engine?.fetchChanges()
    }

    /// Said of a failure, and remembered until a batch goes through whole.
    func failed(_ message: String) {
        lock.withLock { batchFailed = true }
        onStatus?(.failed(message))
    }

    /// A batch that went through whole clears the failure; the status says so.
    func succeeded() {
        lock.withLock { batchFailed = false }
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
        if stores.settings.settings() != nil {
            recordsChanged(.settings, RecordChange(saved: [StudySettings.key]))
        }
    }

    private func id(_ name: SyncName) -> CKRecord.ID {
        CKRecord.ID(recordName: name.recordName, zoneID: zone.zoneID)
    }

    // MARK: The engine

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            try? JSONEncoder().encode(update.stateSerialization).write(
                to: stateURL, options: .store)
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
            if !lock.withLock({ batchFailed }) { onStatus?(.upToDate(Date())) }
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
        if sent.failedRecordSaves.isEmpty, sent.failedRecordDeletes.isEmpty { succeeded() }
        for failure in sent.failedRecordSaves {
            failedSave(failure, retry: &retry, syncEngine)
        }
        saveSystemFields()
        if !retry.isEmpty { syncEngine.state.add(pendingRecordZoneChanges: retry) }
    }

    /// One record the server would not save, by the error: merged and sent again, held
    /// back, or given up on and said.
    private func failedSave(
        _ failure: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave,
        retry: inout [CKSyncEngine.PendingRecordZoneChange], _ syncEngine: CKSyncEngine
    ) {
        let recordID = failure.record.recordID
        switch failure.error.code {
        case .serverRecordChanged:
            // Another device got there first: take its version into the local one, merged,
            // and send the merge on top of it.
            // One this version can't read (written by a newer one) is left as it is.
            guard let server = failure.error.serverRecord, mergeLocally(server) else {
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return
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
            .zoneBusy, .notAuthenticated:
            // The engine tries these again itself.
            break
        case .quotaExceeded:
            // iCloud is full: the engine drops the save; it is held for the next fetch,
            // when there may be room, and the status says why.
            lock.withLock { heldBack.append(.saveRecord(recordID)) }
            failed(failure.error.localizedDescription)
        case .assetFileNotFound, .assetFileModified:
            // The cover changed under the upload: sent again as it is now.
            retry.append(.saveRecord(recordID))
        default:
            failed(failure.error.localizedDescription)
        }
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
        try? JSONEncoder().encode(fields).write(to: fieldsURL, options: .store)
    }
}
