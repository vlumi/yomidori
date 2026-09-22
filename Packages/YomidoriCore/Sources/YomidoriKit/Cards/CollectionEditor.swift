import SwiftUI
import YomidoriCore

/// One collection: its name, note, tags and cover; new when the name is still empty.
struct CollectionEditor: View {
    @State var collection: Collection
    @Environment(\.dismiss) private var dismiss
    @State private var tags = ""
    @State private var scanning = false
    @State private var others: [Collection] = []

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
                TextField(text: $collection.name) {
                    Text("Name", bundle: .module)
                }
                TextField(text: $collection.note) {
                    Text("Note, an author say", bundle: .module)
                }
                TextField(text: $tags) {
                    Text("Tags, comma-separated", bundle: .module)
                }
                let known = others.allTags.filter { tag in
                    !Collection.tags(from: tags).contains { $0.lowercased() == tag.lowercased() }
                }
                if !known.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(known, id: \.self) { tag in
                            Button {
                                tags = (Collection.tags(from: tags) + [tag]).joined(separator: ", ")
                            } label: {
                                Text(verbatim: tag)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }
            } header: {
                Text("Collection", bundle: .module)
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
            tags = collection.tags.joined(separator: ", ")
            others = (Cards.collections?.collections() ?? []).filter { $0.id != collection.id }
        }
        .tint(Palette.nightGreen)
    }

    private func save() {
        var saved = collection
        saved.name = saved.name.trimmingCharacters(in: .whitespaces)
        saved.note = saved.note.trimmingCharacters(in: .whitespaces)
        saved.tags = Collection.tags(from: tags)
        try? Cards.collections?.save(saved)
        dismiss()
    }
}
