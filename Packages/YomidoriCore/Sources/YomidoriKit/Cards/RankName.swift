import SwiftUI
import YomidoriCore

/// A rank as its bird.
struct RankName: View {
    let rank: Rank

    var body: some View {
        switch rank {
        case .nest: Text("Nest", bundle: .module)
        case .egg: Text("Egg", bundle: .module)
        case .hatchling: Text("Hatchling", bundle: .module)
        case .chick: Text("Chick", bundle: .module)
        case .fledgling: Text("Fledgling", bundle: .module)
        case .flying: Text("Flying", bundle: .module)
        case .migrating: Text("Migrating", bundle: .module)
        }
    }
}

/// A rank's symbol in its colour.
struct RankMark: View {
    let rank: Rank

    var body: some View {
        Image(systemName: rank.symbol)
            .foregroundStyle(rank.color)
    }
}

extension Rank {
    /// From the grey of the shelf through the silver egg to greens that deepen as the bird
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

    var symbol: String {
        switch self {
        case .nest: return "basket"
        case .egg: return "oval.portrait.fill"
        case .hatchling: return "bird"
        case .chick: return "bird.fill"
        case .fledgling: return "leaf"
        case .flying: return "wind"
        case .migrating: return "location.north.line"
        }
    }
}
