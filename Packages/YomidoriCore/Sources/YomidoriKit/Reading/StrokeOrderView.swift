import SwiftUI
import YomidoriCore

/// The kanji drawn stroke by stroke over its faint finished form, each stroke numbered
/// where KanjiVG prints the number; a tap draws it again.
struct StrokeOrderView: View {
    let strokes: [KanjiStroke]
    var side: CGFloat = 180
    @State private var drawn = 0
    @State private var drawing: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(strokes.indices, id: \.self) { index in
                let path = Path(stroke: strokes[index], side: side)
                path.stroke(Palette.silver.opacity(0.35), style: style)
                path.trim(from: 0, to: index < drawn ? 1 : 0)
                    .stroke(Palette.nightGreen, style: style)
                if let label = strokes[index].label {
                    Text(verbatim: "\(index + 1)")
                        .font(.system(size: 9))
                        .foregroundStyle(index < drawn ? Color.secondary : Color.clear)
                        .position(x: label.x * scale, y: label.y * scale - 4)
                }
            }
        }
        .frame(width: side, height: side)
        .background(Palette.silver.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { replay() }
        .onAppear { replay() }
        .onDisappear { drawing?.cancel() }
    }

    private var scale: CGFloat { side / KanjiStroke.boxSide }

    private var style: StrokeStyle {
        StrokeStyle(lineWidth: side / 30, lineCap: .round, lineJoin: .round)
    }

    private func replay() {
        drawing?.cancel()
        drawn = 0
        drawing = Task { @MainActor in
            for index in strokes.indices {
                try? await Task.sleep(for: .milliseconds(index == 0 ? 250 : 420))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.35)) { drawn = index + 1 }
            }
        }
    }
}
