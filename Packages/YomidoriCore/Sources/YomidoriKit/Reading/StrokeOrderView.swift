import SwiftUI
import YomidoriCore

/// The kanji drawn stroke by stroke over its faint finished form, each stroke numbered
/// where KanjiVG prints the number; a tap draws it again.
struct StrokeOrderView: View {
    let strokes: [KanjiStroke]
    var side: CGFloat = 180
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1
    @State private var drawn = 0
    @State private var drawing: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(strokes.indices, id: \.self) { index in
                let path = Path(stroke: strokes[index], side: scaledSide)
                path.stroke(Palette.silver.opacity(0.35), style: style)
                path.trim(from: 0, to: index < drawn ? 1 : 0)
                    .stroke(Palette.nightGreen, style: style)
                if let label = strokes[index].label {
                    Text(verbatim: "\(index + 1)")
                        .font(.system(size: 9 * typeScale))
                        .foregroundStyle(index < drawn ? Color.secondary : Color.clear)
                        .position(x: label.x * scale, y: label.y * scale - 4)
                }
            }
        }
        .frame(width: scaledSide, height: scaledSide)
        .background(Palette.silver.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { replay() }
        .onAppear { replay() }
        .onDisappear { drawing?.cancel() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Stroke order, \(strokes.count) strokes", bundle: .module))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Draws the strokes again", bundle: .module))
        .accessibilityAction { replay() }
    }

    private var scaledSide: CGFloat { side * typeScale }

    private var scale: CGFloat { scaledSide / KanjiStroke.boxSide }

    private var style: StrokeStyle {
        StrokeStyle(lineWidth: scaledSide / 30, lineCap: .round, lineJoin: .round)
    }

    private func replay() {
        drawing?.cancel()
        if reduceMotion {
            drawn = strokes.count
            return
        }
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
