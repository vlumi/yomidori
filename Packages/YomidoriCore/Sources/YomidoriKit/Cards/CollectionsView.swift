import SwiftUI
import YomidoriCore

/// The collections with their covers, tags and counts; a tap edits, the plus adds, a swipe
/// removes (which only takes the collection off its cards).
struct CollectionsView: View {
    @State private var collections: [Collection] = []

    var body: some View {
        List {
            ForEach(collections) { collection in
                NavigationLink(value: collection) {
                    CollectionRow(collection: collection, count: count(in: collection))
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    Cards.removeCollection(collections[index])
                }
                reload()
            }
            if collections.isEmpty {
                Text("No collections yet. A book, say.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("Collections", bundle: .module))
        .toolbar {
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
    }

    private func count(in collection: Collection) -> Int {
        (Cards.store?.cards() ?? []).filter { $0.collectionIDs.contains(collection.id) }.count
    }

    private func reload() {
        collections = Cards.collections?.collections() ?? []
    }
}

struct CollectionRow: View {
    let collection: Collection
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            if let coverID = collection.coverID, let image = StillArchive.load(coverID) {
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !collection.tags.isEmpty {
                    Text(verbatim: collection.tags.joined(separator: " · "))
                        .font(.caption2)
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
