import SwiftUI
import YomidoriCore

struct PitchReading: View {
    let reading: String
    let accent: PitchAccent

    var body: some View {
        let morae = PitchAccent.morae(of: reading)
        let marks = accent.marks(forMoraCount: morae.count)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            HStack(spacing: 0) {
                ForEach(morae.indices, id: \.self) { index in
                    Text(verbatim: morae[index])
                        .font(.title3)
                        .overlay(alignment: .top) { PitchMark(mark: marks[index]) }
                }
            }
            .foregroundStyle(Palette.nightGreen)
            .fixedSize()
            Text(verbatim: "[\(accent.downstep)]")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(reading), pitch \(accent.downstep)", bundle: .module))
    }
}

/// A stroke at the mora's end where the pitch drops, at its start where it rises.
private struct PitchMark: View {
    let mark: PitchAccent.Mark
    @ScaledMetric(relativeTo: .title3) private var unit: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let y = -3 * unit
                let drop = 7 * unit
                if mark.high {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                if mark.dropsAfter {
                    path.move(to: CGPoint(x: geometry.size.width, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y + drop))
                }
                if mark.risesBefore {
                    path.move(to: CGPoint(x: geometry.size.width, y: y + drop))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Palette.nightGreen, lineWidth: 1.5 * unit)
        }
    }
}
