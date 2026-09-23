import CoreTransferable
import Foundation
import UniformTypeIdentifiers
import YomidoriCore

extension UTType {
    /// Declared in the app's Info.plist, where the .yomidori extension is tied to it.
    static let yomidoriCollection = UTType(exportedAs: "fi.misaki.yomidori.collection")
}

/// A collection handed to the share sheet as a .yomidori file, written when it is shared.
struct CollectionFile: Transferable {
    let collection: Collection

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .yomidoriCollection) { file in
            let shared = SharedCollection(
                collection: file.collection, cards: Cards.store?.cards() ?? [])
            let name = file.collection.name.components(
                separatedBy: CharacterSet(charactersIn: "/:\\")
            )
            .joined(separator: " ")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(name.isEmpty ? "Yomidori" : name)
                .appendingPathExtension("yomidori")
            try shared.encoded().write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// What an import did, for the note shown after it.
struct CollectionImport: Identifiable {
    let id = UUID()
    let name: String
    let added: Int
    let joined: Int
}

extension Cards {
    /// Into the collection of the same name, or a new one; the words merge into the cards.
    static func importCollection(from url: URL) throws -> CollectionImport {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? .max
        guard size <= SharedCollection.largestFile else { throw CocoaError(.fileReadTooLarge) }
        let shared = try SharedCollection.decoded(from: Data(contentsOf: url))
        guard let store, let collections else { throw CocoaError(.fileReadUnknown) }
        var collection =
            collections.collections().first { $0.name == shared.name }
            ?? Collection(name: shared.name, note: shared.note)
        if collection.note.isEmpty { collection.note = shared.note }
        for tag in shared.tags where !collection.tags.containsTag(tag) {
            collection.tags.append(tag)
        }
        try collections.save(collection)
        var merged: SharedCollection.Merged?
        try store.replaceAll { cards in
            let result = shared.merge(into: cards, collection: collection.id, at: Date())
            merged = result
            return result.cards
        }
        return CollectionImport(
            name: shared.name, added: merged?.added ?? 0, joined: merged?.joined ?? 0)
    }
}
