import SwiftUI
import YomidoriCore

/// Every collection, the card's own ticked; a tap adds or removes it.
struct CardCollections: View {
    @Binding var card: Card
    let save: () -> Void
    @State private var collections: [Collection] = []

    var body: some View {
        if !collections.isEmpty {
            Section {
                ForEach(collections) { collection in
                    let member = card.collectionIDs.contains(collection.id)
                    Button {
                        if member {
                            card.remove(from: collection.id)
                        } else {
                            card.add(to: collection.id)
                        }
                        save()
                    } label: {
                        HStack {
                            Text(verbatim: collection.name)
                            Spacer()
                            if member {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Palette.nightGreen)
                            }
                        }
                    }
                    .tint(.primary)
                }
            } header: {
                Text("Collections", bundle: .module)
            }
            .onAppear { collections = Cards.collections?.collections() ?? [] }
        }
    }
}
