import Charts
import SwiftUI
import YomidoriCore

/// How many cards stand at each rank, as bars from the nest to the migrating bird, each in
/// its color. At rest the caption counts the eggs waiting and every card started, the
/// hatchling up; a finger on a bar shows its number and name instead.
struct RankChart: View {
    let cards: [Card]
    /// One question's ranks, or the cards' own.
    var question: Question?
    @State private var selected: String?

    private struct Bar: Identifiable {
        let rank: Rank
        let count: Int
        var id: Int { rank.rawValue }
        var key: String { "\(rank.rawValue)" }
    }

    private var bars: [Bar] {
        let counts = Dictionary(grouping: cards) { card in
            question.map { card.rank(for: $0) } ?? card.rank
        }.mapValues(\.count)
        return Rank.allCases.map { Bar(rank: $0, count: counts[$0] ?? 0) }
    }

    var body: some View {
        let bars = bars
        let shown = bars.first { $0.key == selected }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let shown {
                    RankMark(rank: shown.rank)
                    RankName(rank: shown.rank)
                    Text(verbatim: "\(shown.count)")
                        .fontWeight(.semibold)
                } else {
                    let eggs = bars.first { $0.rank == .egg }?.count ?? 0
                    let started = bars.filter { $0.rank > .egg }.map(\.count).reduce(0, +)
                    RankMark(rank: .egg)
                    RankName(rank: .egg)
                    Text(verbatim: "\(eggs)")
                        .fontWeight(.semibold)
                    Text(verbatim: "·")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    RankMark(rank: .hatchling)
                    Text("Started", bundle: .module)
                    Text(verbatim: "\(started)")
                        .fontWeight(.semibold)
                }
            }
            .accessibilityElement(children: .combine)
            .font(.callout)
            .frame(minHeight: 30)
            Chart(bars) { bar in
                BarMark(
                    x: .value(String(localized: "Rank", bundle: .module), bar.key),
                    y: .value(String(localized: "Cards", bundle: .module), bar.count)
                )
                .foregroundStyle(
                    bar.rank.color.opacity(selected == nil || selected == bar.key ? 1 : 0.45)
                )
                .cornerRadius(4)
            }
            .chartXSelection(value: $selected)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let key = value.as(String.self), let raw = Int(key),
                            let rank = Rank(rawValue: raw)
                        {
                            RankMark(rank: rank, size: 24)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 120)
        }
    }
}
