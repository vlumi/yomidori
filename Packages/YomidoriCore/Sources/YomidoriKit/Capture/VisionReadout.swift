import SwiftUI
import YomidoriCore

struct VisionReadout: View {
    let lines: [RecognizedLine]
    let selected: Int?

    var body: some View {
        if let selected, lines.indices.contains(selected) {
            let line = lines[selected]
            VStack(spacing: 4) {
                Text(verbatim: line.text)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                Text(line.confidence, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if lines.isEmpty {
            Text("Nothing was recognized.", bundle: .module)
                .foregroundStyle(.secondary)
        } else {
            Text("Tap a line to see what was read.", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }
}
