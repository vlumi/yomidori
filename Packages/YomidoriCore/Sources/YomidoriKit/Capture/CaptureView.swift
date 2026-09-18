import PhotosUI
import SwiftUI
import VisionKit
import YomidoriCore

/// The spike: frame a page and press the shutter, or pick a screenshot, and see
/// what the two recognizers the OS ships read from the still. Vision's lines are
/// boxed over the page, tap one to read it out large; Live Text's transcript is
/// listed, with its own selection over the page. Compared against the book, this
/// answers the roadmap's first question: does on-device recognition read a real
/// paperback, columns included.
public struct CaptureView: View {
    @StateObject private var camera = Camera()
    @State private var still: Still?
    @State private var engine: Engine = .vision
    @State private var lines: [RecognizedLine] = []
    @State private var analysis: ImageAnalysis?
    @StateObject private var selection = LiveTextSelection()
    /// Pages already read in this spread, before the still on screen; their text joins
    /// the current page's at the seam so a word or sentence cut by the page turn is whole.
    @State private var pages: [Page] = []
    @State private var selected: Int?
    @State private var recognizing = false
    @State private var closeUp: CloseUp?
    @State private var readingCloseUp = false
    @State private var picked: PhotosPickerItem?

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let still {
                switch engine {
                case .vision:
                    visionStill(still)
                case .liveText:
                    LiveTextImage(still: still, analysis: analysis, selection: selection)
                case .closeUp:
                    closeUpStill(still)
                }
            } else {
                CameraPreview(camera: camera, access: camera.access).ignoresSafeArea()
                CameraNotice(access: camera.access)
                if !pages.isEmpty {
                    SpreadNotice(startOver: startOver)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { controls }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .task(id: picked) { await loadPicked() }
        .task(id: still?.id) { await recognize() }
    }

    private func visionStill(_ still: Still) -> some View {
        StillView(still: still, lines: lines, selected: selected, highlight: nil, onTap: selectLine)
    }

    private func closeUpStill(_ still: Still) -> some View {
        StillView(
            still: still, lines: lines, selected: nil, highlight: closeUp?.box, onTap: readCloseUp)
    }

    private func selectLine(at point: CGPoint, in frame: CGRect) {
        selected = TextGeometry.lineIndex(at: point, in: frame, lines: lines)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            if still != nil {
                Picker(selection: $engine) {
                    Text("Vision", bundle: .module).tag(Engine.vision)
                    Text("Live Text", bundle: .module).tag(Engine.liveText)
                    Text("Close-up", bundle: .module).tag(Engine.closeUp)
                } label: {
                    Text("Recognizer", bundle: .module)
                }
                .pickerStyle(.segmented)
                readout
                if let still {
                    Text(verbatim: "\(still.image.width) × \(still.image.height)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            HStack {
                if still == nil {
                    PhotosPicker(selection: $picked, matching: .images) {
                        Label {
                            Text("Choose a photo", bundle: .module)
                        } icon: {
                            Image(systemName: "photo.on.rectangle")
                        }
                    }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    Button(action: takeStill) {
                        Circle()
                            .strokeBorder(Palette.nightGreen, lineWidth: 4)
                            .background(Circle().fill(.white))
                            .frame(width: 72, height: 72)
                    }
                    .accessibilityLabel(Text("Shutter", bundle: .module))
                    .disabled(camera.access != .ready)
                    .opacity(camera.access == .ready ? 1 : 0.4)
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                } else {
                    Button(action: retake) {
                        Label {
                            Text("Retake", bundle: .module)
                        } icon: {
                            Image(systemName: "camera")
                        }
                    }
                    .buttonStyle(.bordered)
                    if analysis != nil {
                        Button(action: addPage) {
                            Label {
                                Text("Add next page", bundle: .module)
                            } icon: {
                                Image(systemName: "plus.rectangle.portrait")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    if !pages.isEmpty {
                        Button(action: startOver) {
                            Text("Start over", bundle: .module)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Palette.page)
        .tint(Palette.nightGreen)
    }

    @ViewBuilder private var readout: some View {
        if recognizing {
            ProgressView {
                Text("Reading the page…", bundle: .module)
            }
        } else if engine == .liveText {
            transcript
        } else if engine == .closeUp {
            closeUpReadout
        } else if let selected, lines.indices.contains(selected) {
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

    @ViewBuilder private var transcript: some View {
        if let analysis, analysis.hasResults(for: .text) {
            TranscriptReadout(
                transcript: Spread.join(pages.map(\.transcript) + [analysis.transcript]),
                stills: pages.map(\.still) + [still].compactMap { $0 },
                currentTranscript: analysis.transcript,
                pageOffset: Spread.offset(
                    ofPage: pages.count, in: pages.map(\.transcript) + [analysis.transcript]),
                selection: selection)
        } else if LiveText.isSupported {
            Text("Nothing was recognized.", bundle: .module)
                .foregroundStyle(.secondary)
        } else {
            Text("Live Text is not available on this device.", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var closeUpReadout: some View {
        if readingCloseUp {
            ProgressView {
                Text("Reading up close…", bundle: .module)
            }
        } else if let closeUp {
            HStack(alignment: .top, spacing: 12) {
                Image(decorative: closeUp.crop.image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 160, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 6) {
                    engineLine("Live Text", closeUp.liveText)
                    engineLine("Vision", closeUp.vision)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Tap a word to read it up close.", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }

    private func engineLine(_ name: LocalizedStringKey, _ text: String) -> some View {
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

    /// Cut the line under the tap out of the full-resolution still, whole and with
    /// the paper around it, and read only that: the character reaches the recognizer
    /// at the size the sensor saw it, and no glyph is halved at a crop's edge. Where
    /// the page pass found no line there (a vertical column, say), a square around
    /// the tap stands in.
    private func readCloseUp(at point: CGPoint, in frame: CGRect) {
        guard let still,
            let pixel = TextGeometry.imagePoint(at: point, in: frame, imageSize: still.size)
        else { return }
        let rect: CGRect
        if let index = TextGeometry.lineIndex(at: point, in: frame, lines: lines) {
            let line = TextGeometry.imageRect(for: lines[index].box, imageSize: still.size)
            rect = TextGeometry.padded(line, by: min(line.width, line.height) * 0.8, in: still.size)
        } else {
            let side = max(still.size.width, still.size.height) / 3
            rect = TextGeometry.cropRect(around: pixel, side: side, in: still.size)
        }
        guard let crop = still.cropped(to: rect) else { return }
        let box = TextGeometry.normalizedBox(for: rect, imageSize: still.size)
        readingCloseUp = true
        Task { @MainActor in
            let lines = (try? await TextRecognizer.recognize(crop)) ?? []
            let transcript =
                LiveText.isSupported ? (try? await LiveText.analyze(crop))?.transcript ?? "" : ""
            closeUp = CloseUp(
                box: box, crop: crop, vision: lines.map(\.text).joined(separator: " "),
                liveText: transcript.replacingOccurrences(of: "\n", with: " "))
            readingCloseUp = false
        }
    }

    private func takeStill() {
        Task { @MainActor in
            if let taken = await camera.takeStill() {
                camera.stop()
                still = taken
            }
        }
    }

    /// Keep this page's text and take the next: the camera comes back, and the next
    /// still joins this one in the readout.
    private func addPage() {
        guard let still, let analysis else { return }
        pages.append(Page(still: still, transcript: analysis.transcript))
        retake()
    }

    private func startOver() {
        pages = []
        if still != nil {
            retake()
        }
    }

    private func retake() {
        still = nil
        picked = nil
        camera.start()
    }

    private func loadPicked() async {
        guard let picked, let data = try? await picked.loadTransferable(type: Data.self),
            let loaded = Still(data: data), !Task.isCancelled
        else { return }
        camera.stop()
        still = loaded
    }

    private func recognize() async {
        lines = []
        analysis = nil
        selected = nil
        closeUp = nil
        guard let still else { return }
        recognizing = true
        let recognized = (try? await TextRecognizer.recognize(still)) ?? []
        let analyzed = LiveText.isSupported ? try? await LiveText.analyze(still) : nil
        guard !Task.isCancelled else { return }
        lines = recognized
        analysis = analyzed
        recognizing = false
    }
}

/// The still, aspect-fitted, with each recognized line boxed over it in night
/// green, the selected one filled, and an optional square (the close-up) drawn on
/// top. It pinches to zoom and drags to pan; a double tap brings it back. The tap
/// is reported in the still's own coordinates with the frame it occupies, whatever
/// the zoom, so the geometry seam needs no knowledge of it.
struct StillView: View {
    @State private var zoom = Zoom()
    let still: Still
    let lines: [RecognizedLine]
    let selected: Int?
    let highlight: CGRect?
    let onTap: (CGPoint, CGRect) -> Void

    var body: some View {
        GeometryReader { geometry in
            let frame = TextGeometry.fittedFrame(of: still.size, in: geometry.size)
            ZStack(alignment: .topLeading) {
                Image(decorative: still.image, scale: 1)
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                ForEach(lines.indices, id: \.self) { index in
                    let rect = TextGeometry.viewRect(for: lines[index].box, in: frame)
                    let isSelected = index == selected
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.nightGreen.opacity(isSelected ? 0.35 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Palette.nightGreen, lineWidth: isSelected ? 2 : 1)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
                if let highlight {
                    let rect = TextGeometry.viewRect(for: highlight, in: frame)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Palette.nightGreen, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2).onEnded { _ in zoom = Zoom() }
                    .exclusively(before: SpatialTapGesture().onEnded { onTap($0.location, frame) })
            )
            .zoomable($zoom, in: geometry.size)
            .clipped()
        }
    }
}
