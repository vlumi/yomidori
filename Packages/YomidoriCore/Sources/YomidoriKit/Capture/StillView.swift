import SwiftUI
import YomidoriCore

/// The spread's pages as one picture, zoomed and panned as one: each page its own photo in its
/// own frame, side by side or one under the other. A tap is reported with the page it hit, in
/// that page's own frame, whatever the zoom.
struct StillView: View {
    /// One page of the picture and what is drawn over it.
    struct Sheet {
        let still: Still
        let lines: [RecognizedLine]
        let selected: Set<Int>
        let highlights: [CGRect]
    }

    @Binding var zoom: Zoom
    let sheets: [Sheet]
    let side: SpreadLayout.Side
    let onTap: (_ page: Int, CGPoint, CGRect) -> Void
    var onLongPress: ((_ page: Int, CGPoint, CGRect) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let frames = SpreadLayout.fitted(
                sheets.map(\.still.size), nextOn: side, in: geometry.size)
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(sheets.indices, frames)), id: \.0) { index, frame in
                    sheet(sheets[index], at: index, in: frame)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2).onEnded { _ in zoom = Zoom() }
                    .exclusively(
                        before: SpatialTapGesture().onEnded { tap in
                            hit(tap.location, in: frames, onTap)
                        })
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        if case .second(true, let drag?) = value, let onLongPress {
                            hit(drag.location, in: frames, onLongPress)
                        }
                    },
                including: onLongPress == nil ? .none : .all
            )
            .zoomable($zoom, in: geometry.size)
            .accessibilityAction(named: Text("Reset zoom", bundle: .module)) { zoom = Zoom() }
            .clipped()
        }
    }

    private func hit(
        _ point: CGPoint, in frames: [CGRect], _ action: (Int, CGPoint, CGRect) -> Void
    ) {
        guard let page = SpreadLayout.page(at: point, in: frames) else { return }
        action(page, point, frames[page])
    }

    @ViewBuilder private func sheet(_ sheet: Sheet, at page: Int, in frame: CGRect) -> some View {
        Image(decorative: sheet.still.preview, scale: 1)
            .resizable()
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
        ForEach(sheet.lines.indices, id: \.self) { index in
            let rect = TextGeometry.viewRect(for: sheet.lines[index].box, in: frame)
            let isSelected = sheet.selected.contains(index)
            RoundedRectangle(cornerRadius: 3)
                .fill(Palette.nightGreen.opacity(isSelected ? 0.35 : 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Palette.nightGreen, lineWidth: isSelected ? 2 : 1)
                )
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .accessibilityElement()
                .accessibilityLabel(Text(japanese: sheet.lines[index].text))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { onTap(page, CGPoint(x: rect.midX, y: rect.midY), frame) }
        }
        ForEach(sheet.highlights.indices, id: \.self) { index in
            let rect = TextGeometry.viewRect(for: sheet.highlights[index], in: frame)
            RoundedRectangle(cornerRadius: 4)
                .stroke(Palette.nightGreen, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
    }
}
