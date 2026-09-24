import PhotosUI
import SwiftUI
import VisionKit
import YomidoriCore
import YomidoriDictionary

public struct CaptureView: View {
    @StateObject var camera = Camera()
    @StateObject var selection = LiveTextSelection()
    @EnvironmentObject var page: CaptureState
    @State var recognizing = false
    @State private var readingCloseUp = false
    @State var picked: PhotosPickerItem?
    @StateObject private var zoomControl = ZoomControl()
    @AppStorage(TokenizerChoice.key) var tokenizerChoice: TokenizerChoice = .system
    @AppStorage(SettingsKey.pageControlsSide) private var controlsSide: PageControlsSide = .right
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

    var still: Still? {
        get { page.still }
        nonmutating set { page.still = newValue }
    }
    var pages: [Page] {
        get { page.pages }
        nonmutating set { page.pages = newValue }
    }
    private var mode: Mode {
        get { page.mode }
        nonmutating set { page.mode = newValue }
    }
    var lines: [RecognizedLine] {
        get { page.lines }
        nonmutating set { page.lines = newValue }
    }
    private var analysis: ImageAnalysis? {
        get { page.analysis }
        nonmutating set { page.analysis = newValue }
    }
    var selected: Int? {
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
                } else if let pasted = page.pasted {
                    TextPage(text: pasted, selection: selection)
                        .frame(height: pageArea(in: geometry.size).height)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .onTabReselect(.read) { retake() }
                    drawer(screenHeight: geometry.size.height)
                } else {
                    VStack(spacing: 0) {
                        cameraView
                        drawer(screenHeight: geometry.size.height)
                    }
                }
            }
            .onAppear { if still == nil, page.pasted == nil { camera.start() } }
            .onDisappear { camera.stop() }
            .task(id: picked) { await loadPicked() }
            .onChange(of: page.mode) { clearWord() }
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
                    highlight: page.wordBox,
                    onTap: tapWord)
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
        .overlay(alignment: controlsSide.alignment) {
            PageControls(
                side: controlsSide, pageCount: pages.isEmpty ? nil : pages.count + 1,
                canAddPage: currentTranscript != nil, addPage: addPage, startOver: startOver,
                zoom: zoomFraction(in: area)
            )
            .padding(12)
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

    /// The slider's place: Live Text's scroll view reports its own; the other modes' zoom is
    /// the page state's.
    private func zoomFraction(in area: CGSize) -> Binding<Double> {
        if mode == .liveText {
            return Binding(get: { zoomControl.fraction }, set: { zoomControl.set($0) })
        }
        return Binding(
            get: { Zoom.fraction(of: zoom.scale, in: Zoom.range) },
            set: { zoom = zoom.scaled(to: Zoom.scale(at: $0, in: Zoom.range), in: area) })
    }

    private func drawer(screenHeight: CGFloat) -> some View {
        CaptureDrawer(
            hasStill: still != nil || page.pasted != nil, screenHeight: screenHeight,
            fraction: Binding(get: { liveFraction ?? readoutFraction }, set: { liveFraction = $0 }),
            settled: { fraction in settle(at: DrawerDetents.nearest(fraction)) },
            toggled: toggleDrawer
        ) {
            if page.pasted == nil {
                Picker(selection: $page.mode) {
                    Text("Live Text", bundle: .module).tag(Mode.liveText)
                    Text("Vision", bundle: .module).tag(Mode.vision)
                    Text("Close-up", bundle: .module).tag(Mode.closeUp)
                } label: {
                    Text("Recognizer", bundle: .module)
                }
                .pickerStyle(.segmented)
            }
            readout
            if still != nil || page.pasted != nil {
                Text("Tap Read again for a new page.", bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } buttons: {
            if still == nil, page.pasted == nil {
                CameraButtons(
                    picked: $picked, ready: camera.access == .ready,
                    label: Text("Read the page", bundle: .module), freeze: takeStill,
                    paste: paste)
            }
        }
    }

    @ViewBuilder private var readout: some View {
        if recognizing {
            VStack(spacing: 6) {
                ProgressView {
                    Text("Reading the page…", bundle: .module)
                }
                Text("Blurred or not quite framed? Tap Read to start again.", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else if page.pasted != nil {
            transcript
        } else {
            switch mode {
            case .vision, .liveText:
                transcript
            case .closeUp:
                CloseUpReadout(reading: readingCloseUp, closeUp: closeUp)
            }
        }
    }

    /// The page's text: pasted, Vision's lines in Vision mode, Live Text's, or the one the page
    /// came with.
    var currentTranscript: String? {
        if let pasted = page.pasted { return pasted }
        if mode == .vision, !lines.isEmpty { return VisionPage(lines: lines).transcript }
        if let analysis, analysis.hasResults(for: .text) { return analysis.transcript }
        return page.transcript
    }

    @ViewBuilder private var transcript: some View {
        if let current = currentTranscript {
            let transcripts = pages.map(\.transcript) + [current]
            TranscriptReadout(
                transcript: Spread.join(transcripts),
                currentTranscript: current,
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

    /// A tap on a Vision line lands on a character; the word over it is outlined and given to
    /// the drawer as a selection, as Live Text's would be, so it reads, keeps and fixes alike.
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

    private func recognize() async {
        lines = []
        analysis = nil
        page.transcript = nil
        selected = nil
        page.wordBox = nil
        closeUp = nil
        closeUpTask?.cancel()
        closeUpTask = nil
        readingCloseUp = false
        page.recognizedStillID = nil
        guard let still else { return }
        recognizing = true
        // Both engines at once, as child tasks: a retake cancels this task, and the cancel
        // reaches both instead of waiting for the first to finish.
        async let visionLines = (try? TextRecognizer.recognize(still)) ?? []
        async let liveText = LiveText.isSupported ? try? LiveText.analyze(still) : nil
        let (recognized, analyzed) = await (visionLines, liveText)
        guard !Task.isCancelled, self.still?.id == still.id else { return }
        lines = recognized
        analysis = analyzed
        page.recognizedStillID = still.id
        recognizing = false
        AccessibilityNotification.Announcement(String(localized: "Page read", bundle: .module))
            .post()
    }
}
