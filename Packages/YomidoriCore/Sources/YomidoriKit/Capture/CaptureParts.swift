import SwiftUI
import YomidoriCore

extension CaptureView {
    enum Engine: Hashable {
        case vision
        case liveText
        case closeUp
    }

    /// One reading up close: the square around a tap, and what each engine made of it.
    struct Page {
        let still: Still
        let transcript: String
    }

    struct CloseUp {
        let box: CGRect
        let crop: Still
        let vision: String
        let liveText: String
        /// manga-ocr's reading of a window around the tap; nil where the models are not bundled.
        let mangaOCR: String?
    }
}

/// While a spread is open, the camera is for its next page.
struct SpreadNotice: View {
    let startOver: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Text("Take the next page, or start over.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Palette.silver)
                Button {
                    startOver()
                } label: {
                    Text("Start over", bundle: .module)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, 16)
        }
    }
}

/// Why there is no live image: no camera here, or no permission.
struct CameraNotice: View {
    let access: Camera.Access

    var body: some View {
        switch access {
        case .denied:
            notice("Camera access is off. Turn it on in Settings to frame a page.")
        case .unavailable:
            notice("No camera here. Choose a photo instead.")
        case .undetermined, .ready:
            EmptyView()
        }
    }

    private func notice(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: .module)
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.silver)
            .padding(24)
    }
}

/// The drawer's handle: drag to size it, most of the screen for the page while
/// looking for a word, more drawer once the word is found. Between a fifth and four
/// fifths of the screen; the fraction is the caller's to remember.
struct DrawerHandle: View {
    @Binding var fraction: Double
    let screenHeight: CGFloat
    @GestureState private var fractionAtStart: Double?

    var body: some View {
        Capsule()
            .fill(Palette.silver)
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($fractionAtStart) { _, start, _ in
                        if start == nil { start = fraction }
                    }
                    .onChanged { value in
                        let start = fractionAtStart ?? fraction
                        fraction = min(
                            max(start - value.translation.height / screenHeight, 0.2), 0.8)
                    })
    }
}

/// One engine's reading in the close-up readout: the engine's name small, the text under it.
struct EngineLine: View {
    let name: LocalizedStringKey
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name, bundle: .module)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: text.isEmpty ? "—" : text)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}
