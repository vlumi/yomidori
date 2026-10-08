import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// A lesson: the next few waiting cards as pages to swipe through, each shown whole. A card
/// dropped or put back for later leaves the lesson and the next waiting card takes the
/// tail; the last page starts them all and goes on to the practice over them.
struct LessonView: View {
    @AppStorage(SettingsKey.lessonOrder) private var order: Lesson.Order = .oldest
    @AppStorage(SettingsKey.lessonSize) private var size = 5
    /// The lesson's pages, once begun.
    @State private var cards: [Card]?
    /// The waiting cards after the lesson's, in the lesson's order: the next to pull in.
    @State private var pool: [Card] = []
    /// The page showing, by the card's id.
    @State private var current: UUID?
    @State private var collections: [Collection] = []
    @State private var chosen: Set<UUID> = []
    @EnvironmentObject private var taps: TabTaps
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let cards {
                if cards.isEmpty {
                    emptied
                } else {
                    pager(cards)
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
                        Button {
                            if chosen.contains(collection.id) {
                                chosen.remove(collection.id)
                            } else {
                                chosen.insert(collection.id)
                            }
                        } label: {
                            HStack {
                                Text(verbatim: collection.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if chosen.contains(collection.id) {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Palette.nightGreen)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(chosen.contains(collection.id) ? .isSelected : [])
                    }
                } header: {
                    // All of them ticked to begin with; All and None flip them at once.
                    HStack {
                        Text("Collections", bundle: .module)
                        Spacer()
                        Button {
                            chosen = Set(collections.map(\.id))
                        } label: {
                            Text("All", bundle: .module)
                        }
                        .disabled(chosen.count == collections.count)
                        Button {
                            chosen = []
                        } label: {
                            Text("None", bundle: .module)
                        }
                        .disabled(chosen.isEmpty)
                    }
                    .textCase(nil)
                    .font(.subheadline)
                } footer: {
                    Text("Cards in no collection are always in.", bundle: .module)
                }
            }
            Section {
                Button {
                    begin()
                } label: {
                    Text("Begin", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(candidates.isEmpty)
            }
            .listRowBackground(Color.clear)
        }
        // Grouped on the Mac, as Settings is, and no wider than a page: a bare form ran
        // the window's width with Begin as a bar across it.
        .settingsFormStyle()
        .readingWidth()
        .onAppear {
            collections = Cards.collections?.collections() ?? []
            chosen = Set(collections.map(\.id))
            if DemoMode.beginsLesson { begin() }
        }
    }

    /// The waiting cards of the collections ticked, and the ones in no collection at all,
    /// which no tick could stand for: with every collection unticked, those alone.
    private var candidates: [Card] {
        let existing = Set(collections.map(\.id))
        return (Cards.store?.waiting() ?? []).filter { card in
            card.isInNone(of: existing) || !chosen.isDisjoint(with: card.collectionIDs)
        }
    }

    /// The pages side by side, one card each, snapping page by page; the bar below is the
    /// lesson's, not a page's, so it stays put while the cards slide.
    private func pager(_ cards: [Card]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(cards) { card in
                    LessonCard(card: card) { correct($0, on: card) }
                        .containerRelativeFrame(.horizontal)
                        .id(card.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $current)
        .scrollIndicators(.hidden)
        .readingWidth()
        // A small title over the pages: a large one collapses and grows with the card's own
        // scrolling, resizing the pages under the finger, and the card's list and the title
        // bounce each other at the top without end.
        .navigationBarTitleDisplayModeInline()
        .safeAreaInset(edge: .bottom) { bar(cards) }
        .onAppear { if current == nil { current = cards.first?.id } }
    }

    /// Every card dropped or put back: nothing left to start.
    private var emptied: some View {
        VStack(spacing: 20) {
            Text("Nothing left to start.", bundle: .module)
                .font(.title2)
                .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Text("Done", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .readingWidth()
    }

    /// Where the page stands in the lesson, and what to do with its card: drop it, put it
    /// back for later, or go on — to the next page, or from the last to the practice.
    private func bar(_ cards: [Card]) -> some View {
        let index = cards.firstIndex { $0.id == current } ?? 0
        return VStack(spacing: 10) {
            Text(verbatim: "\(index + 1) / \(cards.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Card \(index + 1) of \(cards.count)", bundle: .module))
            FitsOrStacks {
                actions(at: index, in: cards)
            }
            .controlSize(.large)
            // The pages by the arrow keys too, on a keyboard: buttons with no face of their own.
            .background {
                HStack {
                    Button {
                        if index > 0 { show(cards[index - 1]) }
                    } label: {
                        Text("Previous card", bundle: .module)
                    }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button {
                        if index + 1 < cards.count { show(cards[index + 1]) }
                    } label: {
                        Text("Next card", bundle: .module)
                    }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                }
                .opacity(0)
                .accessibilityHidden(true)
            }
        }
        .padding(16)
        .background(Palette.page)
    }

    @ViewBuilder
    private func actions(at index: Int, in cards: [Card]) -> some View {
        let card = cards[index]
        Button(role: .destructive) {
            drop(card)
        } label: {
            Text("Drop", bundle: .module).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .keyboardShortcut(.delete, modifiers: .command)
        .help(Text("Drop the card (⌘⌫)", bundle: .module))
        Button {
            putBack(card)
        } label: {
            Text("Later", bundle: .module).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .keyboardShortcut("l", modifiers: .command)
        .help(Text("Put it back for later (⌘L)", bundle: .module))
        if index == cards.count - 1 {
            Button {
                startPractice(cards)
            } label: {
                Text("Start practice", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .help(Text("Start the cards and practice them (↩)", bundle: .module))
        } else {
            Button {
                show(cards[index + 1])
            } label: {
                Text("Next", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .help(Text("The next card (↩)", bundle: .module))
        }
    }

    private func begin() {
        let dictionary = JMdict.bundled
        let ordered = Lesson.pick(from: candidates, order: order, size: candidates.count) { card in
            dictionary?.entry(headword: card.headword, reading: card.reading)?.common ?? false
        }
        cards = Array(ordered.prefix(size))
        pool = Array(ordered.dropFirst(size))
        current = cards?.first?.id
    }

    private func show(_ card: Card) {
        withAnimation { current = card.id }
    }

    /// A sentence corrected in the lesson: on the stored card, and on the one shown.
    private func correct(_ sighting: Sighting, on card: Card) {
        var changed = Cards.store?.card(id: card.id) ?? card
        changed.replace(sighting)
        Cards.write { try Cards.store?.update(changed) }
        cards = cards?.map { $0.id == changed.id ? changed : $0 }
    }

    private func drop(_ card: Card) {
        Cards.write { try Cards.store?.remove(card) }
        replace(card)
    }

    /// Back to the waiting stack, as it was: out of this lesson only.
    private func putBack(_ card: Card) {
        replace(card)
    }

    /// The card leaves the lesson and the next waiting card takes the tail; the page stays
    /// where it was, now showing the card that moved up into it.
    private func replace(_ card: Card) {
        guard var pages = cards, let index = pages.firstIndex(where: { $0.id == card.id }) else {
            return
        }
        pages.remove(at: index)
        if !pool.isEmpty { pages.append(pool.removeFirst()) }
        cards = pages
        current = pages.isEmpty ? nil : pages[min(index, pages.count - 1)].id
    }

    /// Every card still in the lesson is started — seen through to the end is accepted —
    /// and the practice over them takes the lesson's place.
    private func startPractice(_ cards: [Card]) {
        let now = Date()
        for card in cards {
            // The stored card, which another device may have changed since the lesson began.
            var changed = Cards.store?.card(id: card.id) ?? card
            changed.start(at: now)
            Cards.write { try Cards.store?.update(changed) }
        }
        taps.open(.practice(cards.map(\.id)), in: .study)
    }
}
