import SwiftUI
import YomidoriCore

/// What is done to the cards picked in the list, together: put in a collection, or taken
/// out of one. Each is one write, so one change goes to the other devices.
struct CardsBatch: View {
    let picked: Set<UUID>
    let cards: [Card]
    let collections: [Collection]

    /// The collections some picked card is in: the ones there is something to take out of.
    private var holding: [Collection] {
        let held = Set(cards.filter { picked.contains($0.id) }.flatMap(\.collectionIDs))
        return collections.filter { held.contains($0.id) }
    }

    var body: some View {
        // One row: the count, and the two things to do, their names shown where they fit.
        ViewThatFits(in: .horizontal) {
            row(labels: true)
            row(labels: false)
        }
        .buttonStyle(.bordered)
        .tint(Palette.nightGreen)
    }

    private func row(labels: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(picked.count) selected", bundle: .module)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
            Menu {
                ForEach(collections) { collection in
                    Button {
                        Cards.write { try Cards.store?.add(picked, to: collection.id) }
                    } label: {
                        Text(verbatim: collection.name)
                    }
                }
            } label: {
                label(Text("Add to…", bundle: .module), "folder.badge.plus", shown: labels)
            }
            .disabled(picked.isEmpty || collections.isEmpty)
            .accessibilityLabel(Text("Add to a collection", bundle: .module))
            .help(Text("Add to a collection", bundle: .module))
            Menu {
                ForEach(holding) { collection in
                    Button(role: .destructive) {
                        Cards.write { try Cards.store?.remove(picked, from: collection.id) }
                    } label: {
                        Text(verbatim: collection.name)
                    }
                }
            } label: {
                label(Text("Take out of…", bundle: .module), "folder.badge.minus", shown: labels)
            }
            .disabled(holding.isEmpty)
            .accessibilityLabel(Text("Take out of a collection", bundle: .module))
            .help(Text("Take out of a collection", bundle: .module))
        }
    }

    @ViewBuilder private func label(_ title: Text, _ symbol: String, shown: Bool) -> some View {
        if shown {
            Label {
                title.lineLimit(1).fixedSize()
            } icon: {
                Image(systemName: symbol)
            }
        } else {
            Image(systemName: symbol)
        }
    }
}
