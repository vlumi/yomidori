import SwiftUI
import YomidoriCore

/// One collection: its name, note, tags and cover; new when the name is still empty.
struct CollectionEditor: View {
    @State var collection: Collection
    @Environment(\.dismiss) private var dismiss
    @State private var scanning = false
    @State private var others: [Collection] = []
    /// The cover on record, and the ones scanned here: files nothing refers to until Save.
    @State private var persistedCoverID: UUID?
    @State private var scannedCoverIDs: Set<UUID> = []
    @State private var saved = false
    @State private var isSaved = false

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    if let coverID = collection.coverID, let image = StillArchive.load(coverID) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            scanning = true
                        } label: {
                            Label {
                                Text("Scan the cover", bundle: .module)
                            } icon: {
                                Image(systemName: "camera.viewfinder")
                            }
                        }
                        if collection.coverID != nil {
                            Button(role: .destructive) {
                                collection.coverID = nil
                            } label: {
                                Label {
                                    Text("Remove the cover", bundle: .module)
                                } icon: {
                                    Image(systemName: "photo.badge.minus")
                                }
                            }
                        }
                    }
                }
            } footer: {
                Text(
                    "The words on the cover are read, so the name can be picked, not typed.",
                    bundle: .module)
            }
            Section {
                LabeledContent {
                    TextField(text: $collection.name) {
                        Text("Required", bundle: .module)
                    }
                    .multilineTextAlignment(.trailing)
                } label: {
                    Text("Name", bundle: .module)
                }
                LabeledContent {
                    TextField(text: $collection.note) {
                        Text("An author, say", bundle: .module)
                    }
                    .multilineTextAlignment(.trailing)
                } label: {
                    Text("Note", bundle: .module)
                }
            }
            TagsEditor(tags: $collection.tags, known: others.allTags)
            if isSaved {
                Section {
                    ShareLink(
                        item: CollectionFile(collection: collection),
                        preview: SharePreview(collection.name)
                    ) {
                        Label {
                            Text("Share this collection", bundle: .module)
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                } footer: {
                    Text(
                        // swiftlint:disable:next line_length
                        "The words and the sentences they were met in, for another reader to start fresh; no photos, no cover, no reviews.",
                        bundle: .module)
                }
            }
        }
        .navigationTitle(Text(verbatim: collection.name.isEmpty ? "" : collection.name))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    Text("Save", bundle: .module)
                }
                .disabled(collection.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $scanning) {
            CoverScanView(collection: $collection)
        }
        .onAppear {
            let all = Cards.collections?.collections() ?? []
            others = all.filter { $0.id != collection.id }
            persistedCoverID = all.first { $0.id == collection.id }?.coverID
            isSaved = all.contains { $0.id == collection.id }
        }
        .onChange(of: collection.coverID) { _, scanned in
            if let scanned, scanned != persistedCoverID { scannedCoverIDs.insert(scanned) }
        }
        .onDisappear {
            if !saved { removeCovers(scannedCoverIDs) }
        }
        .tint(Palette.nightGreen)
    }

    private func save() {
        var record = collection
        record.name = record.name.trimmingCharacters(in: .whitespaces)
        record.note = record.note.trimmingCharacters(in: .whitespaces)
        try? Cards.collections?.save(record)
        saved = true
        var stale = scannedCoverIDs
        if let old = persistedCoverID, old != record.coverID { stale.insert(old) }
        if let kept = record.coverID { stale.remove(kept) }
        removeCovers(stale)
        dismiss()
    }

    private func removeCovers(_ ids: Set<UUID>) {
        StillArchive.remove(Array(ids), keptBy: Cards.store?.cards() ?? [])
    }
}
