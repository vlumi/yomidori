import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// A kanji found by the parts the reader can see in it: tap parts, pick from the kanji that
/// have them all, and it joins the search; the sheet stays for the next one, so a word is
/// built kanji by kanji. Parts that no longer lead anywhere dim.
struct KanjiByPartsView: View {
    @Binding var query: String
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [KanjiPart.Group] = []
    @State private var chosen: [String] = []
    @State private var matches: [String] = []
    @State private var possible: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                queryLine
                matchesStrip
                Divider()
                partsGrid
            }
            .navigationTitle(Text("Kanji by parts", bundle: .module))
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !chosen.isEmpty {
                        Button {
                            chosen = []
                        } label: {
                            Text("Clear", bundle: .module)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done", bundle: .module)
                    }
                }
            }
            .task { groups = KanjiPart.byStrokes(JMdict.bundled?.kanjiParts() ?? []) }
            .task(id: chosen) {
                matches = JMdict.bundled?.kanji(withParts: chosen, limit: 300) ?? []
                possible = JMdict.bundled?.parts(foundWith: chosen) ?? []
            }
        }
        .presentationDetents([.large])
    }

    private var queryLine: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(japanese: query)
                .font(.title2)
                .lineLimit(1)
            Spacer()
            if !query.isEmpty {
                Button {
                    query.removeLast()
                } label: {
                    Label {
                        Text("Delete the last character", bundle: .module)
                    } icon: {
                        Image(systemName: "delete.left")
                    }
                }
                .labelStyle(.iconOnly)
                .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var matchesStrip: some View {
        if chosen.isEmpty {
            Text("Tap the parts you see in the kanji.", bundle: .module)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 64)
        } else if matches.isEmpty {
            Text("No kanji has all of these parts.", bundle: .module)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 64)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 6) {
                    ForEach(matches, id: \.self) { kanji in
                        Button {
                            query.append(kanji)
                            chosen = []
                        } label: {
                            Text(japanese: kanji)
                                .font(.largeTitle)
                                .frame(minWidth: 56, minHeight: 56)
                        }
                        .buttonStyle(.bordered)
                        .tint(Palette.nightGreen)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 72)
            .scrollIndicators(.hidden)
        }
    }

    private var partsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 4)], spacing: 4) {
                ForEach(groups, id: \.strokes) { group in
                    Text(verbatim: group.strokes.map(String.init) ?? "…")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(
                            Palette.nightGreen.opacity(0.8), in: RoundedRectangle(cornerRadius: 6)
                        )
                        .accessibilityLabel(
                            group.strokes.map { Text("\($0) strokes", bundle: .module) }
                                ?? Text(verbatim: "…"))
                    ForEach(group.parts) { part in
                        partButton(part)
                    }
                }
            }
            .padding(12)
        }
    }

    private func partButton(_ part: KanjiPart) -> some View {
        let isChosen = chosen.contains(part.component)
        let leads = chosen.isEmpty || isChosen || possible.contains(part.component)
        return Button {
            if isChosen {
                chosen.removeAll { $0 == part.component }
            } else {
                chosen.append(part.component)
            }
        } label: {
            Text(japanese: part.glyph)
                .font(.title2)
                .frame(width: 46, height: 46)
                .background(
                    isChosen ? Palette.nightGreen.opacity(0.3) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .opacity(leads ? 1 : 0.2)
        .disabled(!leads)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
