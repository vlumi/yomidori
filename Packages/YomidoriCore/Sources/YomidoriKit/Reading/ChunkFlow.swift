import SwiftUI
import YomidoriCore

#if os(macOS)
import AppKit
#endif

/// One line of the page as its chunks, the readings over the words; the selected ones lit.
/// A tap selects a word, a long press stretches the selection to it.
struct ChunkFlow: View {
    let chunks: [PageReading.Chunk]
    let selected: Range<Int>?
    let select: (PageReading.Chunk) -> Void
    let extend: (PageReading.Chunk) -> Void
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(chunks) { chunk in
                let isSelected = selected?.overlaps(chunk.range) == true
                let reading = chunk.isWord && chunk.word.reading != chunk.surface
                VStack(spacing: 0) {
                    Text(verbatim: reading ? chunk.word.reading : " ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(verbatim: chunk.surface)
                        .font(.title3)
                        .foregroundStyle(chunk.isWord ? .primary : .secondary)
                }
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Palette.nightGreen.opacity(0.25) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Palette.nightGreen, lineWidth: isSelected && differentiate ? 2 : 0)
                )
                .contentShape(Rectangle())
                #if os(macOS)
                // Shift-click stretches the selection, as in any text; the long press stays
                // for a finger. (iOS has no shift on a tap; a trackpad's secondary click
                // opens the menu, which extends.)
                .gesture(TapGesture().modifiers(.shift).onEnded { extend(chunk) })
                .onHover { over in
                    if over { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                #else
                .hoverEffect(.highlight)
                #endif
                .onTapGesture { if chunk.isWord { select(chunk) } }
                .onLongPressGesture { extend(chunk) }
                .contextMenu {
                    if chunk.isWord {
                        Button {
                            select(chunk)
                        } label: {
                            Text("Select", bundle: .module)
                        }
                    }
                    Button {
                        extend(chunk)
                    } label: {
                        Text("Extend the selection to here", bundle: .module)
                    }
                    Button {
                        Clipboard.copy(chunk.surface)
                    } label: {
                        Text("Copy", bundle: .module)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    Text(
                        japanese: reading ? "\(chunk.surface)、\(chunk.word.reading)" : chunk.surface
                    )
                )
                .accessibilityAddTraits(chunk.isWord ? .isButton : [])
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityAction(named: Text("Extend the selection to here", bundle: .module)) {
                    extend(chunk)
                }
            }
        }
    }
}
