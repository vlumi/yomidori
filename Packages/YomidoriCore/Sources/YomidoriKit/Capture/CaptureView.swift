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
    enum Engine: Hashable {
        case vision
        case liveText
    }

    @StateObject private var camera = Camera()
    @State private var still: Still?
    @State private var engine: Engine = .vision
    @State private var lines: [RecognizedLine] = []
    @State private var analysis: ImageAnalysis?
    @State private var selected: Int?
    @State private var recognizing = false
    @State private var picked: PhotosPickerItem?

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let still {
                switch engine {
                case .vision:
                    StillView(still: still, lines: lines, selected: $selected)
                case .liveText:
                    LiveTextImage(still: still, analysis: analysis)
                }
            } else {
                CameraPreview(camera: camera, access: camera.access).ignoresSafeArea()
                cameraNotice
            }
        }
        .safeAreaInset(edge: .bottom) { controls }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .task(id: picked) { await loadPicked() }
        .task(id: still?.id) { await recognize() }
    }

    @ViewBuilder private var cameraNotice: some View {
        switch camera.access {
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

    private var controls: some View {
        VStack(spacing: 16) {
            if still != nil {
                Picker(selection: $engine) {
                    Text("Vision", bundle: .module).tag(Engine.vision)
                    Text("Live Text", bundle: .module).tag(Engine.liveText)
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
            ScrollView {
                Text(verbatim: analysis.transcript)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)
        } else if LiveText.isSupported {
            Text("Nothing was recognized.", bundle: .module)
                .foregroundStyle(.secondary)
        } else {
            Text("Live Text is not available on this device.", bundle: .module)
                .foregroundStyle(.secondary)
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
/// green; the tapped line is filled.
struct StillView: View {
    let still: Still
    let lines: [RecognizedLine]
    @Binding var selected: Int?

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
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { point in
                selected = TextGeometry.lineIndex(at: point, in: frame, lines: lines)
            }
        }
    }
}
