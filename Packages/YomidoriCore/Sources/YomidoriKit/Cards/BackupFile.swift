import CoreTransferable
import Foundation
import UniformTypeIdentifiers
import YomidoriCore

/// The backup handed to the share sheet, written when it is shared.
struct BackupFile: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { _ in
            SentTransferredFile(try Cards.writeBackup())
        }
    }
}

/// What a restore did, for the note shown after it.
struct BackupRestore: Identifiable, Sendable {
    let id = UUID()
    let addedCards: Int
    let joinedCards: Int
    let addedCollections: Int
}

extension Cards {
    /// The cards, the collections and the lookup history as one dated file.
    static func writeBackup() throws -> URL {
        let backup = Backup(
            created: Date(), cards: store?.cards() ?? [],
            collections: collections?.collections() ?? [], lookups: lookups?.lookups() ?? [])
        let url = try Cards.shareFolder()
            .appendingPathComponent(Backup.fileName(at: Date()))
            .appendingPathExtension("json")
        try backup.encoded().write(to: url, options: .store)
        return url
    }

    /// A backup's contents added to what is here; nothing here is taken away.
    /// The restore off the main thread, as the import.
    static func restoreBackup(from url: URL) async throws -> BackupRestore {
        try await Task.detached(priority: .userInitiated) { try restoreBackup(from: url) }.value
    }

    nonisolated static func restoreBackup(from url: URL) throws -> BackupRestore {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? .max
        guard size <= Backup.largestFile else { throw CocoaError(.fileReadTooLarge) }
        let backup = try Backup.decoded(from: Data(contentsOf: url))
        guard let store, let collections, let lookups else { throw CocoaError(.fileReadUnknown) }
        let restored = try backup.restore(
            cards: store, collections: collections, lookups: lookups)
        return BackupRestore(
            addedCards: restored.addedCards, joinedCards: restored.joinedCards,
            addedCollections: restored.addedCollections)
    }
}

extension Cards {
    /// Where a file to share is written: a folder of its own under tmp, emptied for each
    /// share, so a copy of every card never sits there longer than the next share.
    static func shareFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
            "share", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
