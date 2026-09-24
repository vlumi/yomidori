import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// A kanji found by the parts the reader can see in it: tap parts, pick from the kanji that
/// have them all, and the sheet closes with it; the search puts it at its cursor. Parts that
/// no longer lead anywhere dim.
struct KanjiByPartsView: View {
    let pick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [KanjiPart.Group] = []
    @State private var chosen: [String] = []
    @State private var matches: [String] = []
    @State private var possible: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                matchesStrip
                Divider()
                partsGrid
            }
            .navigationTitle(Text("Kanji by parts", bundle: .module))
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !chosen.isEmpty {
                        Button {
                            chosen = []
                        } label: {
                            Text("Clear", bundle: .module)
                        }
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
                            pick(kanji)
                            dismiss()
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
