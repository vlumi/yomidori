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

/// A rank as its number, 0 for the nest to 6 for the migrating bird, on a dot of its color;
/// the one mark that reads at any size until a bird is drawn for each.
struct RankMark: View {
    let rank: Rank
    var size: CGFloat = 26

    var body: some View {
        Text(verbatim: "\(rank.rawValue)")
            .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(rank.color, in: Circle())
    }
}

extension Rank {
    /// From the gray of the shelf through the silver egg to greens that deepen as the bird
    /// grows, and the blue of the sky it leaves by.
    var color: Color {
        switch self {
        case .nest: return Color(red: 0.55, green: 0.52, blue: 0.48)
        case .egg: return Palette.silver
        case .hatchling: return Color(red: 0.62, green: 0.78, blue: 0.55)
        case .chick: return Color(red: 0.36, green: 0.66, blue: 0.45)
        case .fledgling: return Palette.nightGreen
        case .flying: return Color(red: 0.12, green: 0.42, blue: 0.50)
        case .migrating: return Color(red: 0.16, green: 0.28, blue: 0.58)
        }
    }
}
