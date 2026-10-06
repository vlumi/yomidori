import SwiftUI
import YomidoriCore

/// The collections with their covers, tags and counts; a tap edits, the plus adds, a swipe
/// or the row's menu removes (which only takes the collection off its cards).
struct CollectionsView: View {
    @State private var collections: [Collection] = []
    @State private var importing = false
    @State private var imported: CollectionImport?
    @State private var failed = false
    /// How many cards each collection has, counted when the lists load, not per row.
    @State private var counts: [UUID: Int] = [:]

    var body: some View {
        List {
            ForEach(collections) { collection in
                NavigationLink(value: collection) {
                    CollectionRow(collection: collection, count: counts[collection.id] ?? 0)
                }
                // The Mac has no swipe; the menu is the row's way, on every platform.
                .contextMenu {
                    Button(role: .destructive) {
                        remove(collection)
                    } label: {
                        Label {
                            Text("Remove the collection", bundle: .module)
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .onDelete { offsets in
                // Taken before the first removal reloads the list under the loop.
                for collection in offsets.map({ collections[$0] }) { remove(collection) }
            }
            if collections.isEmpty {
                Text("No collections yet. A book, say.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("Collections", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    importing = true
                } label: {
                    Label {
                        Text("Import a collection…", bundle: .module)
                    } icon: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: Collection(name: "")) {
                    Label {
                        Text("New collection…", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear(perform: reload)
        .onReceive(Cards.changes(of: [.collection, .card])) { _ in reload() }
        .fileImporter(
            isPresented: $importing, allowedContentTypes: [.yomidoriCollection, .json]
        ) { result in
            guard let url = try? result.get() else { return }
            Task {
                if let done = try? await Cards.importCollection(from: url) {
                    imported = done
                    reload()
                } else {
                    failed = true
                }
            }
        }
        .collectionImportAlerts(imported: $imported, failed: $failed)
    }

    private func remove(_ collection: Collection) {
        Cards.removeCollection(collection)
        reload()
    }

    private func reload() {
        collections = Cards.collections?.collections() ?? []
        var counted: [UUID: Int] = [:]
        for card in Cards.store?.cards() ?? [] {
            for id in card.collectionIDs { counted[id, default: 0] += 1 }
        }
        counts = counted
    }
}

struct CollectionRow: View {
    let collection: Collection
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            if let coverID = collection.coverID, let image = CoverArchive.load(coverID) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Palette.silver.opacity(0.3))
                    .frame(width: 40, height: 56)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: collection.name)
                if !collection.note.isEmpty {
                    Text(verbatim: collection.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !collection.tags.isEmpty {
                    Text(verbatim: collection.tags.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(Palette.nightGreen)
                }
            }
            Spacer()
            Text(verbatim: "\(count)")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("\(count) cards", bundle: .module))
        }
    }
}
