import SwiftUI
import YomidoriCore

/// A rank as its bird.
struct RankName: View {
    let rank: Rank

    var body: some View {
        Self.text(for: rank)
    }

    static func text(for rank: Rank) -> Text {
        switch rank {
        case .nest: return Text("Nest", bundle: .module)
        case .egg: return Text("Egg", bundle: .module)
        case .hatchling: return Text("Hatchling", bundle: .module)
        case .chick: return Text("Chick", bundle: .module)
        case .fledgling: return Text("Fledgling", bundle: .module)
        case .flying: return Text("Flying", bundle: .module)
        case .migrating: return Text("Migrating", bundle: .module)
        }
    }
}

/// A rank as its number, 0 for the egg to 5 for the migrating bird, on a dot of its color;
/// the nest, outside the climb, shows a dash.
struct RankMark: View {
    let rank: Rank
    var size: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = size * scale
        Group {
            if let number = rank.number {
                Text(verbatim: "\(number)")
            } else {
                Text(verbatim: "–")
            }
        }
        .font(.system(size: side * 0.7, weight: .bold, design: .rounded))
        .foregroundStyle(rank.markForeground)
        .frame(width: side, height: side)
        .background(rank.color, in: Circle())
    }
}

extension Rank {
    /// A walk round the hue circle with a step in lightness at each rank, so neighbours
    /// differ in both and read apart with or without full color vision (checked: every
    /// adjacent pair over ΔE 15 normal and 8 simulated, light and dark surface alike): the
    /// nest's gray, the egg's silver, a hatchling's yellow down, a chick's green, the night
    /// green of the fledgling, the sky blue it flies into, the indigo of the far horizon.
    var color: Color {
        switch self {
        case .nest: return Color(red: 0.54, green: 0.51, blue: 0.47)
        case .egg: return Color(red: 0.85, green: 0.84, blue: 0.80)
        case .hatchling: return Color(red: 0.90, green: 0.76, blue: 0.10)
        case .chick: return Color(red: 0.20, green: 0.60, blue: 0.25)
        case .fledgling: return Color(red: 0.09, green: 0.36, blue: 0.26)
        case .flying: return Color(red: 0.11, green: 0.47, blue: 0.67)
        case .migrating: return Color(red: 0.23, green: 0.18, blue: 0.62)
        }
    }

    /// The numeral's color: black on the three light dots, white from the chick's green on,
    /// where black read dull on the green and the blue though it measured as well.
    var markForeground: Color {
        switch self {
        case .chick, .fledgling, .flying, .migrating: return .white
        case .nest, .egg, .hatchling: return .black
        }
    }
}
