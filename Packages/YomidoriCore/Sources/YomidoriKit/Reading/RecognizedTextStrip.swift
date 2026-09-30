import SwiftUI
import YomidoriCore

/// The recognized text as its chunks, line by line, under a title that folds it and stays
/// put while it scrolls; a tap selects a word, a long press stretches the selection.
struct RecognizedTextStrip: View {
    let reading: PageReading
    @EnvironmentObject private var page: CaptureState
    @AppStorage(SettingsKey.transcriptExpanded) private var expanded = false

    var body: some View {
        Section {
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(reading.lines.lines.indices, id: \.self) { line in
                        ChunkFlow(
                            chunks: reading.chunks.filter { $0.line == line },
                            selected: page.selectedRange,
                            select: { page.selectedRange = $0.range },
                            extend: page.extendSelection)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack {
                    Text("Recognized text", bundle: .module)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Palette.page)
            .accessibilityAddTraits(expanded ? [.isSelected] : [])
        }
    }
}
