import Charts
import SwiftUI
import YomidoriCore

/// How many cards stand at each rank, as bars from the nest to the migrating bird, each in
/// its color; a finger on a bar shows its number and name.
struct RankChart: View {
    let cards: [Card]
    @State private var selected: String?

    private struct Bar: Identifiable {
        let rank: Rank
        let count: Int
        var id: Int { rank.rawValue }
        var key: String { "\(rank.rawValue)" }
    }

    private var bars: [Bar] {
        let counts = Dictionary(grouping: cards, by: \.rank).mapValues(\.count)
        return Rank.allCases.map { Bar(rank: $0, count: counts[$0] ?? 0) }
    }

    var body: some View {
        let bars = bars
        let shown = bars.first { $0.key == selected } ?? bars.max { $0.count < $1.count }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let shown {
                    RankMark(rank: shown.rank)
                    RankName(rank: shown.rank)
                    Text(verbatim: "\(shown.count)")
                        .fontWeight(.semibold)
                }
            }
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
