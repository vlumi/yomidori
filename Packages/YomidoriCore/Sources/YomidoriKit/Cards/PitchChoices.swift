import SwiftUI
import YomidoriCore

/// Every pattern the reading allows, drawn as it would be printed; the reader picks one.
struct PitchChoices: View {
    let reading: String
    let pick: (PitchAccent) -> Void

    var body: some View {
        let patterns = PitchAccent.patterns(forMoraCount: PitchAccent.morae(of: reading).count)
        // Columns as wide as the screen allows: two on the smallest phone, where a flow of
        // chips put one to a row and pushed the question off the screen.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            ForEach(patterns, id: \.downstep) { pattern in
                Button {
                    pick(pattern)
                } label: {
                    PitchReading(reading: reading, accent: pattern)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                // The digits pick, 0 for flat, on a keyboard.
                .keyboardShortcut(
                    KeyEquivalent(Character(String(pattern.downstep % 10))), modifiers: []
                )
                .accessibilityLabel(
                    pattern.downstep == 0
                        ? Text("Flat", bundle: .module)
                        : Text("Drops after mora \(pattern.downstep)", bundle: .module))
            }
        }
    }
}
