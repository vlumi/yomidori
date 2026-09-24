import Foundation
import SwiftUI
import YomidoriCore
import YomidoriSync

/// Sync with the reader's own iCloud, on unless turned off in Settings; never in the demo.
@MainActor
final class Sync: ObservableObject {
    static let shared = Sync()
    static let containerIdentifier = "iCloud.fi.misaki.yomidori"

    enum Status: Equatable {
        case off
        case noAccount
        case syncing
        case upToDate
        case failed(String)
    }

    @Published private(set) var status: Status = .off
    /// The engine, read from the stores' callbacks on any thread.
    nonisolated static var engine: CloudSync? {
        engineLock.withLock { current }
    }
    private nonisolated(unsafe) static var current: CloudSync?
    private nonisolated static let engineLock = NSLock()

    /// A change made here: to the engine, or kept for when sync is on again.
    nonisolated static func recordsChanged(_ kind: SyncKind, _ change: RecordChange) {
        engineLock.withLock {
            if let current {
                current.recordsChanged(kind, change)
            } else {
                keepUnsent { $0.note(kind, change) }
            }
        }
    }

    nonisolated static func historyCleared() {
        engineLock.withLock {
            if let current {
                current.historyCleared()
            } else {
                keepUnsent { $0.noteHistoryCleared() }
            }
        }
    }

    /// Called under `engineLock`; not in the demo, whose changes never sync.
    private nonisolated static func keepUnsent(_ note: (inout UnsentChanges) -> Void) {
        guard !DemoMode.isRequested, let url = unsentURL else { return }
        var unsent = UnsentChanges.read(from: url)
        note(&unsent)
        try? unsent.write(to: url)
    }

    private nonisolated static var unsentURL: URL? {
        try? Cards.directory().appendingPathComponent("sync-unsent.json")
    }

    func start() {
        guard Self.engine == nil, !DemoMode.isRequested,
            Cards.defaults.object(forKey: SettingsKey.iCloudSync) as? Bool ?? true
        else { return }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            status = .noAccount
            return
        }
        guard let stores = Cards.syncStores, let directory = try? Cards.directory() else { return }
        let engine = CloudSync(
            containerIdentifier: Self.containerIdentifier, stores: stores, directory: directory)
        engine.onStatus = { [weak engine] status in
            Task { @MainActor in
                // An engine stopped since has nothing more to say.
                guard let engine, Sync.engine === engine else { return }
                switch status {
                case .syncing: Sync.shared.status = .syncing
                case .upToDate: Sync.shared.status = .upToDate
                case .failed(let message): Sync.shared.status = .failed(message)
                }
            }
        }
        // Under the lock, so no change falls between what was kept and the engine taking over.
        Self.engineLock.withLock {
            if let url = Self.unsentURL {
                engine.send(UnsentChanges.read(from: url))
                try? UnsentChanges().write(to: url)
            }
            Self.current = engine
        }
        status = .syncing
    }

    func stop() {
        let engine = Self.engineLock.withLock { () -> CloudSync? in
            defer { Self.current = nil }
            return Self.current
        }
        status = .off
        Task { await engine?.stop() }
    }

    func fetch() {
        Task { await Self.engine?.fetch() }
    }
}
