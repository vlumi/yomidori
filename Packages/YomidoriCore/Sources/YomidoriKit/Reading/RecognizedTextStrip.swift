import SwiftUI
import YomidoriCore

/// The recognized text as its chunks, line by line, under a title that folds it and stays
/// put while it scrolls; a tap selects a word, a long press stretches the selection.
struct RecognizedTextStrip: View {
    let reading: PageReading
    @AppStorage(SettingsKey.transcriptExpanded) private var expanded = false

    var body: some View {
        Section {
            if expanded {
                Lines(reading: reading)
            }
        } header: {
            Header(expanded: $expanded)
                .background(Palette.page)
        }
    }

    /// The title, and the chevron that says whether the lines are shown.
    struct Header: View {
        @Binding var expanded: Bool

        var body: some View {
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
            .accessibilityAddTraits(expanded ? [.isSelected] : [])
        }
    }

    /// The lines as their chunks.
    struct Lines: View {
        let reading: PageReading
        @EnvironmentObject private var page: CaptureState

        var body: some View {
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
    }
}
