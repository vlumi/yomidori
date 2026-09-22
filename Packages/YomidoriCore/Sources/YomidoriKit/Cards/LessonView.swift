import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// A lesson: the next few waiting cards, each shown whole, started, put back or dropped;
/// then the review over the ones started.
struct LessonView: View {
    @AppStorage("lessonOrder") private var order: Lesson.Order = .oldest
    @AppStorage("lessonSize") private var size = 5
    @State private var cards: [Card]?
    @State private var started: [Card] = []
    @State private var collections: [Collection] = []
    @State private var chosen: Set<UUID> = []

    var body: some View {
        Group {
            if let cards {
                if let card = cards.first {
                    LessonCard(card: card) { verdict in advance(card, verdict) }
                } else {
                    finished
                }
            } else {
                setup
            }
        }
        .navigationTitle(Text("Lesson", bundle: .module))
        .tint(Palette.nightGreen)
    }

    private var setup: some View {
        Form {
            Section {
                Picker(selection: $order) {
                    Text("Oldest first", bundle: .module).tag(Lesson.Order.oldest)
                    Text("Newest first", bundle: .module).tag(Lesson.Order.newest)
                    Text("Random", bundle: .module).tag(Lesson.Order.random)
                    Text("Common words first", bundle: .module).tag(Lesson.Order.common)
                } label: {
                    Text("Order", bundle: .module)
                }
                Stepper(value: $size, in: 1...20) {
                    Text("\(size) cards", bundle: .module)
                }
            } footer: {
                Text("\(candidates.count) waiting", bundle: .module)
            }
            if !collections.isEmpty {
                Section {
                    ForEach(collections) { collection in
                        Toggle(isOn: membership(of: collection)) {
                            Text(verbatim: collection.name)
                        }
                    }
                } header: {
                    Text("Collections", bundle: .module)
                } footer: {
                    Text("None chosen means all of them.", bundle: .module)
                }
            }
            Section {
                Button {
                    begin()
                } label: {
                    Text("Begin", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(candidates.isEmpty)
            }
            .listRowBackground(Color.clear)
        }
        .onAppear { collections = Cards.collections?.collections() ?? [] }
    }

    private var candidates: [Card] {
        (Cards.store?.waiting() ?? []).filter { card in
            chosen.isEmpty || !chosen.isDisjoint(with: card.collectionIDs)
        }
    }

    private func membership(of collection: Collection) -> Binding<Bool> {
        Binding {
            chosen.contains(collection.id)
        } set: { on in
            if on { chosen.insert(collection.id) } else { chosen.remove(collection.id) }
        }
    }

    private var finished: some View {
        VStack(spacing: 20) {
            Text("\(started.count) started", bundle: .module)
                .font(.title2)
            if !started.isEmpty {
                NavigationLink(value: Screen.review) {
                    Text("Review them now", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(24)
    }

    private func begin() {
        let dictionary = JMdict.bundled
        cards = Lesson.pick(from: candidates, order: order, size: size) { card in
            dictionary?.entry(headword: card.headword, reading: card.reading)?.common ?? false
        }
    }

    private func advance(_ card: Card, _ verdict: LessonCard.Verdict) {
        var changed = card
        switch verdict {
        case .start:
            changed.start(at: Date())
            try? Cards.store?.update(changed)
            started.append(changed)
        case .later:
            break
        case .drop:
            try? Cards.store?.remove(card)
        }
        cards?.removeFirst()
    }
}
