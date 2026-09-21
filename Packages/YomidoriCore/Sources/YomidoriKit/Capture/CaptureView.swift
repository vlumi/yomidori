import PhotosUI
import SwiftUI
import VisionKit
import YomidoriCore

/// The page: the camera until the shutter, then the still with what the engines
/// read from it, in a drawer the reader sizes. Several pages can be read as one.
public struct CaptureView: View {
    @StateObject private var camera = Camera()
    @StateObject private var selection = LiveTextSelection()
    @State private var still: Still?
    @State private var pages: [Page] = []
    @State private var engine: Engine = .vision
    @State private var lines: [RecognizedLine] = []
    @State private var analysis: ImageAnalysis?
    @State private var selected: Int?
    @State private var recognizing = false
    @State private var closeUp: CloseUp?
    @State private var readingCloseUp = false
    @State private var picked: PhotosPickerItem?
    @AppStorage("readoutFraction") private var readoutFraction = 0.32

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if let still {
                    stillView(still)
                } else {
                    CameraPreview(camera: camera, access: camera.access, shutter: takeStill)
                        .ignoresSafeArea()
                    CameraNotice(access: camera.access)
                    if !pages.isEmpty {
                        SpreadNotice(startOver: startOver)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { drawer(screenHeight: geometry.size.height) }
            .onAppear { camera.start() }
            .onDisappear { camera.stop() }
            .task(id: picked) { await loadPicked() }
            .task(id: still?.id) { await recognize() }
        }
    }

    @ViewBuilder private func stillView(_ still: Still) -> some View {
        switch engine {
        case .vision:
            StillView(
                still: still, lines: lines, selected: selected, highlight: nil, onTap: selectLine)
        case .liveText:
            LiveTextImage(still: still, analysis: analysis, selection: selection)
        case .closeUp:
            StillView(
                still: still, lines: lines, selected: nil, highlight: closeUp?.box,
                onTap: readCloseUp)
        }
    }

    private func drawer(screenHeight: CGFloat) -> some View {
        CaptureDrawer(
            hasStill: still != nil, screenHeight: screenHeight, fraction: $readoutFraction
        ) {
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
        } buttons: {
            if still == nil {
                CameraButtons(picked: $picked, ready: camera.access == .ready, shutter: takeStill)
            } else {
                StillButtons(
                    canAddPage: analysis != nil, hasPages: !pages.isEmpty, retake: retake,
                    addPage: addPage, startOver: startOver)
            }
        }
    }

    @ViewBuilder private var readout: some View {
        if recognizing {
            ProgressView {
                Text("Reading the page…", bundle: .module)
            }
        } else {
            switch engine {
            case .vision:
                VisionReadout(lines: lines, selected: selected)
            case .liveText:
                transcript
            case .closeUp:
                CloseUpReadout(reading: readingCloseUp, closeUp: closeUp)
            }
        }
    }

    @ViewBuilder private var transcript: some View {
        if let analysis, analysis.hasResults(for: .text) {
            let transcripts = pages.map(\.transcript) + [analysis.transcript]
            TranscriptReadout(
                transcript: Spread.join(transcripts),
                stills: pages.map(\.still) + [still].compactMap { $0 },
                currentTranscript: analysis.transcript, currentLines: lines,
                pageOffset: Spread.offset(ofPage: pages.count, in: transcripts),
                selection: selection)
        } else if LiveText.isSupported {
            Text("Nothing was recognized.", bundle: .module)
                .foregroundStyle(.secondary)
        } else {
            Text("Live Text is not available on this device.", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }

    private func selectLine(at point: CGPoint, in frame: CGRect) {
        selected = TextGeometry.lineIndex(at: point, in: frame, lines: lines)
    }

    private func readCloseUp(at point: CGPoint, in frame: CGRect) {
        guard let still,
            let geometry = CloseUpGeometry(
                tap: point, in: frame, lines: lines, imageSize: still.size)
        else { return }
        readingCloseUp = true
        Task { @MainActor in
            closeUp = await CloseUpReader.read(still, at: geometry)
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
