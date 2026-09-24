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
        Self.engineLock.withLock { Self.current = engine }
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
