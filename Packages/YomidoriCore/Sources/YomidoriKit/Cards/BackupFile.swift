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
    /// The cards, the collections with their covers and the lookup history as one dated file.
    static func writeBackup() throws -> URL {
        let collections = collections?.collections() ?? []
        var covers: [UUID: Data] = [:]
        for id in collections.compactMap(\.coverID) {
            covers[id] = (try? CoverArchive.url(for: id)).flatMap { try? Data(contentsOf: $0) }
        }
        let backup = Backup(
            created: Date(), cards: store?.cards() ?? [], collections: collections,
            lookups: lookups?.lookups() ?? [], covers: covers)
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
        let backup = try Backup.decoded(from: readImport(url, largest: Backup.largestFile))
        guard let store, let collections, let lookups else { throw CocoaError(.fileReadUnknown) }
        // The covers first, so a collection's row finds its cover when it reloads.
        restoreCovers(of: backup)
        let restored = try backup.restore(
            cards: store, collections: collections, lookups: lookups)
        return BackupRestore(
            addedCards: restored.addedCards, joinedCards: restored.joinedCards,
            addedCollections: restored.addedCollections)
    }
}

extension Cards {
    /// The file's covers that its collections point at and this device has no file for,
    /// each decoded with care and drawn anew, never copied as it came.
    nonisolated private static func restoreCovers(of backup: Backup) {
        for id in Set(backup.collections.compactMap(\.coverID)) {
            guard let data = backup.covers[id], let url = try? CoverArchive.url(for: id),
                !FileManager.default.fileExists(atPath: url.path),
                let image = ImageIntake.image(
                    from: data, longestSide: Int(CoverArchive.longestSide))
            else { continue }
            _ = try? CoverArchive.save(image, as: id)
        }
    }

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
