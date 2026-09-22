import PhotosUI
import SwiftUI
import VisionKit
import YomidoriCore

public struct CaptureView: View {
    @StateObject private var camera = Camera()
    @StateObject private var selection = LiveTextSelection()
    @EnvironmentObject private var page: CaptureState
    @State private var recognizing = false
    @State private var readingCloseUp = false
    @State private var picked: PhotosPickerItem?
    @State private var zoomControl = ZoomControl()
    @State private var closeUpTask: Task<Void, Never>?
    @AppStorage(SettingsKey.readoutFraction) private var readoutFraction = DrawerDetents.all[0]
    /// The drawer's height the page is laid out to: the fraction as the last drag left it,
    /// so the page reaches the drawer's edge and moves only when the finger lifts.
    @State private var settledFraction: Double?
    /// The fraction under the finger; written to the stored one only on release, since a
    /// defaults write per frame is what made the drawer lag.
    @State private var liveFraction: Double?
    /// Where the drawer stood before a double tap took it to its largest.
    @State private var fractionBeforeToggle: Double?

    public init() {}

    private var still: Still? {
        get { page.still }
        nonmutating set { page.still = newValue }
    }
    private var pages: [Page] {
        get { page.pages }
        nonmutating set { page.pages = newValue }
    }
    private var mode: Mode {
        get { page.mode }
        nonmutating set { page.mode = newValue }
    }
    private var lines: [RecognizedLine] {
        get { page.lines }
        nonmutating set { page.lines = newValue }
    }
    private var analysis: ImageAnalysis? {
        get { page.analysis }
        nonmutating set { page.analysis = newValue }
    }
    private var selected: Int? {
        get { page.selected }
        nonmutating set { page.selected = newValue }
    }
    private var closeUp: CloseUp? {
        get { page.closeUp }
        nonmutating set { page.closeUp = newValue }
    }
    private var zoom: Zoom {
        get { page.zoom }
        nonmutating set { page.zoom = newValue }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                if let still {
                    stillView(still, in: pageArea(in: geometry.size))
                    drawer(screenHeight: geometry.size.height)
                } else {
                    VStack(spacing: 0) {
                        cameraView
                        drawer(screenHeight: geometry.size.height)
                    }
                }
            }
            .onAppear { if still == nil { camera.start() } }
            .onDisappear { camera.stop() }
            .task(id: picked) { await loadPicked() }
            .task(id: still?.id) {
                guard still?.id != page.recognizedStillID else { return }
                zoom =
                    still.map { Zoom.fillingWidth(of: $0.size, in: pageArea(in: geometry.size)) }
                    ?? Zoom()
                await recognize()
            }
        }
    }

    /// The page above the drawer where it settled; while a drag is on, the drawer lies over
    /// the page or leaves a gap, and the page follows on release.
    private func pageArea(in screen: CGSize) -> CGSize {
        CGSize(
            width: screen.width,
            height: screen.height
                - DrawerDetents.height(
                    fraction: settledFraction ?? readoutFraction, screenHeight: screen.height))
    }

    private var cameraView: some View {
        ZStack {
            CameraPreview(camera: camera, access: camera.access, freeze: takeStill)
                .ignoresSafeArea()
            CameraNotice(access: camera.access)
            if !pages.isEmpty {
                SpreadNotice(startOver: startOver)
            }
        }
    }

    private func stillView(_ still: Still, in area: CGSize) -> some View {
        Group {
            switch mode {
            case .vision:
                StillView(
                    zoom: $page.zoom, still: still, lines: lines, selected: selected,
                    highlight: nil,
                    onTap: selectLine)
            case .liveText:
                LiveTextImage(
                    still: still, analysis: analysis, selection: selection,
                    zoomControl: zoomControl)
            case .closeUp:
                StillView(
                    zoom: $page.zoom, still: still, lines: lines, selected: nil,
                    highlight: closeUp?.box, onTap: readCloseUp)
            }
        }
        .frame(width: area.width, height: area.height)
        .overlay(alignment: .bottomTrailing) {
            ZoomButtons { factor in zoomPage(by: factor, in: area) }
                .padding(.trailing, 12)
                .padding(.bottom, 64)
        }
        .overlay(alignment: .bottomLeading) {
            PageButton(
                symbol: "plus", label: Text("Add next page", bundle: .module), action: addPage
            )
            .disabled(currentTranscript == nil)
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            if !pages.isEmpty {
                StartOverButton(pageCount: pages.count + 1, action: startOver)
                    .padding(12)
            }
        }
        // Tapping Read while a page is up is the retake.
        .onTabReselect(.read) { retake() }
        // The tall frame comes after the overlays, or they align to the screen's bottom and
        // sit under the drawer, unseen.
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// The drawer comes to rest at a detent; the page follows.
    private func settle(at fraction: Double) {
        withAnimation(.easeOut(duration: 0.2)) {
            readoutFraction = fraction
            liveFraction = nil
            settledFraction = fraction
        }
    }

    private func toggleDrawer() {
        let largest = DrawerDetents.all.last ?? 0.8
        if readoutFraction >= largest {
            settle(at: fractionBeforeToggle ?? DrawerDetents.all[0])
            fractionBeforeToggle = nil
        } else {
            fractionBeforeToggle = readoutFraction
            settle(at: largest)
        }
    }

    private func zoomPage(by factor: CGFloat, in area: CGSize) {
        if mode == .liveText {
            zoomControl.zoom(by: factor)
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { zoom = zoom.stepped(by: factor, in: area) }
        }
    }

    private func drawer(screenHeight: CGFloat) -> some View {
        CaptureDrawer(
            hasStill: still != nil, screenHeight: screenHeight,
            fraction: Binding(get: { liveFraction ?? readoutFraction }, set: { liveFraction = $0 }),
            settled: { fraction in settle(at: DrawerDetents.nearest(fraction)) },
            toggled: toggleDrawer
        ) {
            Picker(selection: $page.mode) {
                Text("Live Text", bundle: .module).tag(Mode.liveText)
                Text("Vision", bundle: .module).tag(Mode.vision)
                Text("Close-up", bundle: .module).tag(Mode.closeUp)
            } label: {
                Text("Recognizer", bundle: .module)
            }
            .pickerStyle(.segmented)
            readout
            if still != nil {
                Text("Tap Read again for a new page.", bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } buttons: {
            if still == nil {
                CameraButtons(
                    picked: $picked, ready: camera.access == .ready,
                    label: Text("Read the page", bundle: .module), freeze: takeStill)
            }
        }
    }

    @ViewBuilder private var readout: some View {
        if recognizing {
            ProgressView {
                Text("Reading the page…", bundle: .module)
            }
        } else {
            switch mode {
            case .vision:
                VisionReadout(lines: lines, selected: selected)
            case .liveText:
                transcript
            case .closeUp:
                CloseUpReadout(reading: readingCloseUp, closeUp: closeUp)
            }
        }
    }

    /// The page's text: Live Text's, or the one the page came with.
    private var currentTranscript: String? {
        if let analysis, analysis.hasResults(for: .text) { return analysis.transcript }
        return page.transcript
    }

    @ViewBuilder private var transcript: some View {
        if let current = currentTranscript {
            let transcripts = pages.map(\.transcript) + [current]
            TranscriptReadout(
                transcript: Spread.join(transcripts),
                stills: pages.map(\.still) + [still].compactMap { $0 },
                currentTranscript: current, currentLines: lines,
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
        closeUpTask?.cancel()
        closeUpTask = Task { @MainActor in
            let read = await CloseUpReader.read(still, at: geometry)
            guard !Task.isCancelled else { return }
            closeUp = read
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
        guard let still, let transcript = currentTranscript else { return }
        pages.append(Page(still: still, transcript: transcript))
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
        page.transcript = nil
        selected = nil
        closeUp = nil
        closeUpTask?.cancel()
        closeUpTask = nil
        readingCloseUp = false
        page.recognizedStillID = nil
        guard let still else { return }
        recognizing = true
        let recognized = (try? await TextRecognizer.recognize(still)) ?? []
        let analyzed = LiveText.isSupported ? try? await LiveText.analyze(still) : nil
        guard !Task.isCancelled else { return }
        lines = recognized
        analysis = analyzed
        page.recognizedStillID = still.id
        recognizing = false
        AccessibilityNotification.Announcement(String(localized: "Page read", bundle: .module))
            .post()
    }
}
