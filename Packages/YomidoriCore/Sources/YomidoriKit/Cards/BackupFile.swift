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
struct BackupRestore: Identifiable {
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
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(Backup.fileName(at: Date()))
            .appendingPathExtension("json")
        try backup.encoded().write(to: url, options: .atomic)
        return url
    }

    /// A backup's contents added to what is here; nothing here is taken away.
    static func restoreBackup(from url: URL) throws -> BackupRestore {
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
