import SwiftUI
import YomidoriCore

/// A rank as its bird.
struct RankName: View {
    let rank: Rank

    var body: some View {
        switch rank {
        case .egg: Text("Egg", bundle: .module)
        case .hatchling: Text("Hatchling", bundle: .module)
        case .chick: Text("Chick", bundle: .module)
        case .fledgling: Text("Fledgling", bundle: .module)
        case .flying: Text("Flying", bundle: .module)
        case .migrating: Text("Migrating", bundle: .module)
        case .nest: Text("Nest", bundle: .module)
        }
    }
}

/// How many cards stand at each rank, the ranks with none left out.
struct RankCounts: View {
    let cards: [Card]

    var body: some View {
        let counts = Dictionary(grouping: cards, by: \.rank).mapValues(\.count)
        HStack(spacing: 14) {
            ForEach(Rank.allCases.filter { counts[$0] != nil }, id: \.self) { rank in
                VStack(spacing: 2) {
                    Text(verbatim: "\(counts[rank] ?? 0)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.nightGreen)
                    RankName(rank: rank)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
