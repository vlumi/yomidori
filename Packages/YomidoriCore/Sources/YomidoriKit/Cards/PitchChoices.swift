import SwiftUI
import YomidoriCore

/// Every pattern the reading allows, drawn as it would be printed; the reader picks one.
struct PitchChoices: View {
    let reading: String
    let pick: (PitchAccent) -> Void

    var body: some View {
        let patterns = PitchAccent.patterns(forMoraCount: PitchAccent.morae(of: reading).count)
        FlowLayout(spacing: 10) {
            ForEach(patterns, id: \.downstep) { pattern in
                Button {
                    pick(pattern)
                } label: {
                    PitchReading(reading: reading, accent: pattern)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(
                    pattern.downstep == 0
                        ? Text("Flat", bundle: .module)
                        : Text("Drops after mora \(pattern.downstep)", bundle: .module))
            }
        }
    }
}
