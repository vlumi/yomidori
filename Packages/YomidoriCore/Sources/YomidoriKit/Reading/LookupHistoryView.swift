import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// What the search tab shows while the field is empty: the words looked up, newest first,
/// from a search or from a page; a swipe forgets one, the button all.
struct LookupHistoryView: View {
    /// Bumped by the owner when the history was cleared, so the list reloads.
    var generation = 0
    @State private var lookups: [Lookup] = []
    @State private var kept: Set<String> = []

    var body: some View {
        // The Clear button lives on the search screen: a toolbar on any container inside a
        // list lands on every row.
        Section {
            if lookups.isEmpty {
                Text("Words you look up gather here.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(lookups) { lookup in
                if let entry = JMdict.bundled?.entry(withID: lookup.entryID) {
                    NavigationLink(value: entry) {
                        HStack(spacing: 12) {
                            EntryRow(entry: entry, kept: kept.contains(lookup.id))
                            Image(systemName: lookup.source == .page ? "camera" : "magnifyingglass")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    try? Cards.lookups?.remove(lookups[index])
                }
                reload()
            }
        }
        .task(id: generation) { reload() }
    }

    private func reload() {
        lookups = Cards.lookups?.lookups() ?? []
        kept = Cards.keptWords()
    }
}
