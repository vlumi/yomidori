import SwiftUI
import YomidoriCore

/// How the card list is arranged and what it lets through: the sort, which is also the
/// grouping — by rank, or by the month a card was made or last changed — and the kind of
/// word, read off the dictionary.
struct CardListOrder: View {
    @Binding var sort: CardSort
    @Binding var wordClass: WordClass?

    var body: some View {
        Menu {
            Picker(selection: $sort) {
                ForEach(CardSort.allCases, id: \.self) { sort in
                    Self.name(of: sort)
                }
            } label: {
                Text("Sort by", bundle: .module)
            }
            .pickerStyle(.inline)
            Section {
                Picker(selection: $wordClass) {
                    Text("Every kind of word", bundle: .module).tag(WordClass?.none)
                    ForEach(WordClass.allCases, id: \.self) { wordClass in
                        Self.name(of: wordClass).tag(WordClass?.some(wordClass))
                    }
                } label: {
                    Text("Show", bundle: .module)
                }
                .pickerStyle(.inline)
            }
        } label: {
            Label {
                Text("Sort and filter", bundle: .module)
            } icon: {
                Image(
                    systemName: wordClass == nil
                        ? "arrow.up.arrow.down" : "line.3.horizontal.decrease.circle.fill")
            }
        }
        .help(Text("Sort and filter the cards", bundle: .module))
    }

    static func name(of sort: CardSort) -> Text {
        switch sort {
        case .rank: return Text("Rank", bundle: .module)
        case .created: return Text("Date kept", bundle: .module)
        case .modified: return Text("Date changed", bundle: .module)
        }
    }

    static func name(of wordClass: WordClass) -> Text {
        switch wordClass {
        case .noun: return Text("Nouns", bundle: .module)
        case .verb: return Text("Verbs", bundle: .module)
        case .adjective: return Text("Adjectives", bundle: .module)
        case .adverb: return Text("Adverbs", bundle: .module)
        case .expression: return Text("Expressions", bundle: .module)
        case .other: return Text("Other words", bundle: .module)
        }
    }

    /// A section's title: the rank's bird, or the month.
    static func title(of group: CardSort.Group) -> Text {
        switch group {
        case .rank(let rank): return RankName.text(for: rank)
        case .month(let month): return Text(month, format: .dateTime.year().month(.wide))
        }
    }
}

/// A section's header: its title and count, and a chevron that folds it away.
struct CardSectionHeader: View {
    let group: CardSort.Group
    let count: Int
    @Binding var collapsed: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { collapsed.toggle() }
        } label: {
            HStack {
                if case .rank(let rank) = group {
                    RankMark(rank: rank, size: 18)
                }
                CardListOrder.title(of: group)
                Text(verbatim: "\(count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(collapsed ? -90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            collapsed ? Text("Folded", bundle: .module) : Text("Unfolded", bundle: .module))
    }
}
