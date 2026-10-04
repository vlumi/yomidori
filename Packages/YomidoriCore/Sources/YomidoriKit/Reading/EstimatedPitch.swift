import SwiftUI
import YomidoriCore

/// A pitch that was worked out, not looked up: each accent phrase drawn on its own, and the
/// word that says so after them.
struct EstimatedPitch: View {
    let phrases: [PitchPhrase]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ForEach(Array(phrases.enumerated()), id: \.offset) { _, phrase in
                PitchReading(reading: phrase.reading, accent: phrase.accent)
            }
            Text("estimated", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
    }
}
