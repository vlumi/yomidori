import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// What the search tab shows while the field is empty: the words looked up, newest first,
/// from a search or from a page; a swipe or the line's menu forgets one, the button all.
struct LookupHistoryView: View {
    /// Bumped by the owner when the history was cleared, so the list reloads.
    var generation = 0
    /// Where a line opens its entry, given; else it pushes as a link does.
    var open: ((DictionaryEntry) -> Void)?
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
                    Group {
                        if let open {
                            Button {
                                open(entry)
                            } label: {
                                line(entry, lookup)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: entry) {
                                line(entry, lookup)
                            }
                        }
                    }
                    // The Mac has no swipe; the menu is the line's way, on every platform.
                    .contextMenu {
                        Button(role: .destructive) {
                            forget(lookup)
                        } label: {
                            Label {
                                Text("Forget this lookup", bundle: .module)
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .onDelete { offsets in
                // Taken before the first removal reloads the list under the loop.
                for lookup in offsets.map({ lookups[$0] }) { forget(lookup) }
            }
        }
        .task(id: generation) { reload() }
        .onReceive(Cards.changes(of: [.lookup, .card])) { _ in reload() }
    }

    private func line(_ entry: DictionaryEntry, _ lookup: Lookup) -> some View {
        HStack(spacing: 12) {
            EntryRow(
                entry: entry, accent: JMdict.bundled?.pitchAccent(of: entry),
                estimate: JMdict.bundled?.estimatedPitch(of: entry) ?? [],
                kept: kept.contains(lookup.id))
            Image(systemName: lookup.source == .page ? "camera" : "magnifyingglass")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    Text(lookup.source == .page ? "From a page" : "From a search", bundle: .module))
        }
        .contentShape(Rectangle())
    }

    private func forget(_ lookup: Lookup) {
        Cards.write { try Cards.lookups?.remove(lookup) }
        reload()
    }

    private func reload() {
        lookups = Cards.lookups?.lookups() ?? []
        kept = Cards.keptWords()
    }
}
