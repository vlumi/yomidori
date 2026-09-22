import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// What the search tab shows while the field is empty: the words looked up, newest first,
/// from a search or from a page; a swipe forgets one, the button all.
struct LookupHistoryView: View {
    @State private var lookups: [Lookup] = []
    @State private var kept: Set<String> = []

    var body: some View {
        Group {
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
        .toolbar {
            if !lookups.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        try? Cards.lookups?.clear()
                        reload()
                    } label: {
                        Text("Clear", bundle: .module)
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        lookups = Cards.lookups?.lookups() ?? []
        kept = Cards.keptWords()
    }
}
