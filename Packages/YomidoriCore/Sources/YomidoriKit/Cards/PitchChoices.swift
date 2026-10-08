import SwiftUI
import YomidoriCore

/// Every pattern the reading allows, drawn as it would be printed; the reader picks one.
struct PitchChoices: View {
    let reading: String
    let pick: (PitchAccent) -> Void

    /// The Mac always has a keyboard; a phone's hint would only be noise.
    static var showsKeys: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

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
                        // The key that picks it, shown where a keyboard is the way: the
                        // downstep's own number, 0 for flat — the patterns stand in that
                        // order, so the row reads 0, 1, 2… as it is typed.
                        .overlay(alignment: .topLeading) {
                            if Self.showsKeys {
                                Text(verbatim: "\(pattern.downstep % 10)")
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.quaternary, in: Capsule())
                                    .padding(.leading, -4)
                                    .padding(.top, -2)
                                    .accessibilityHidden(true)
                            }
                        }
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
