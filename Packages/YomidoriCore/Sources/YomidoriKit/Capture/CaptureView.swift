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
    @State var picked: PhotosPickerItem?
    @StateObject private var zoomControl = ZoomControl()
    @AppStorage(TokenizerChoice.key) var tokenizerChoice: TokenizerChoice = .system
    @AppStorage(SettingsKey.pageControlsSide) private var controlsSide: PageControlsSide = .right
    /// Where the drawer rests, and where the page is laid out to: it moves only when the
    /// finger lifts, so the page reaches the drawer's edge and follows on release.
    @AppStorage(SettingsKey.readoutFraction) private var readoutFraction = DrawerDetents.all[0]
    /// The fraction under the finger; written to the stored one only on release, since a
    /// defaults write per frame is what made the drawer lag.
    @State private var liveFraction: Double?
    /// Where the drawer stood before a double tap took it to its largest.
    @State private var fractionBeforeToggle: Double?
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The words column's width when the page stands beside it.
    static let wordsWidth: CGFloat = 440

    public init() {}

    var still: Still? {
        get { page.still }
        nonmutating set { page.still = newValue }
    }
    var pages: [Page] {
        get { page.pages }
        nonmutating set { page.pages = newValue }
    }
    var mode: Mode {
        get { page.mode }
        nonmutating set { page.mode = newValue }
    }
    var lines: [RecognizedLine] {
        get { page.lines }
        nonmutating set { page.lines = newValue }
    }
    var analysis: ImageAnalysis? {
        get { page.analysis }
        nonmutating set { page.analysis = newValue }
    }
    private var zoom: Zoom {
        get { page.zoom }
        nonmutating set { page.zoom = newValue }
    }

    public var body: some View {
        GeometryReader { geometry in
            Group {
                if columns(in: geometry.size) {
                    // Room beside the page, an iPad on its side: the words in a column of
                    // their own, as on the Mac, and no drawer.
                    HStack(spacing: 0) {
                        pagePane(in: pageArea(in: geometry.size))
                        wordsColumn
                    }
                } else {
                    ZStack(alignment: .bottom) {
                        pagePane(in: pageArea(in: geometry.size))
                        drawer(screenHeight: geometry.size.height)
                    }
                }
            }
            .onAppear {
                OrientationLock.portrait(true)
                if still == nil, page.pasted == nil { camera.start() }
            }
            .onDisappear {
                OrientationLock.portrait(false)
                camera.stop()
            }
            .task(id: picked) { await loadPicked() }
            .onChange(of: page.mode) { page.selectedRange = nil }
            // A still from outside, while the camera was up: the camera rests.
            .onChange(of: still?.id) { if still != nil { camera.stop() } }
            .task(id: still?.id) {
                guard still?.id != page.recognizedStillID else { return }
                // The spread as one sheet, filling the width.
                let sheet = SpreadLayout.arrange(
                    spreadPages.compactMap(\.still?.size), nextOn: spreadSide
                ).size
                zoom =
                    sheet.width > 0
                    ? Zoom.fillingWidth(of: sheet, in: pageArea(in: geometry.size)) : Zoom()
                await recognize()
            }
        }
    }

    /// A regular width lying down: the page and the words side by side.
    private func columns(in screen: CGSize) -> Bool {
        sizeClass == .regular && screen.width > screen.height
    }

    /// The page's room: beside the words column, or above the drawer where it settled; while
    /// a drag is on, the drawer lies over the page or leaves a gap, and the page follows on
    /// release.
    private func pageArea(in screen: CGSize) -> CGSize {
        if columns(in: screen) {
            return CGSize(width: screen.width - Self.wordsWidth, height: screen.height)
        }
        return CGSize(
            width: screen.width,
            height: screen.height
                - DrawerDetents.height(fraction: readoutFraction, screenHeight: screen.height))
    }

    /// The still, the pasted text or the camera, in its room, over black.
    @ViewBuilder private func pagePane(in area: CGSize) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let still {
                stillView(still, in: area)
            } else if let pasted = page.pasted {
                TextPage(text: pasted, selection: selection)
                    .frame(height: area.height)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .onTabReselect(.read) { retake() }
            } else {
                cameraView
            }
        }
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
                    zoom: $page.zoom, sheets: visionSheets, side: spreadSide,
                    onTap: tapWord, onLongPress: extendWord)
            case .liveText:
                LiveTextImage(
                    sheets: spreadPages.compactMap { sheet in
                        sheet.still.map { LiveTextImage.Sheet(still: $0, analysis: sheet.analysis) }
                    }, side: spreadSide, selection: selection, zoomControl: zoomControl)
            }
        }
        .frame(width: area.width, height: area.height)
        // The page is being read: said over the whole picture, not only in the drawer, and
        // the picture still zooms and pans under it.
        .overlay {
            if recognizing {
                ZStack {
                    Color.black.opacity(0.35)
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                        Text("Reading the page…", bundle: .module)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: recognizing)
        .overlay(alignment: controlsSide.alignment) {
            PageControls(
                side: controlsSide, pageCount: pages.isEmpty ? nil : pages.count + 1,
                canAddPage: currentTranscript != nil && pages.count + 1 < Self.pagesInASpread,
                addPage: addPage, startOver: startOver,
                moveNextPage: pages.count + 1 < Self.pagesInASpread ? nil : moveNextPage,
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
        }
    }

    private func toggleDrawer() {
        let toggled = DrawerDetents.toggled(from: readoutFraction, remembered: fractionBeforeToggle)
        fractionBeforeToggle = toggled.remember
        settle(at: toggled.settle)
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
            toggled: toggleDrawer, content: { words }, buttons: { buttons })
    }

    /// The words beside the page: what the drawer holds, standing, with the buttons under.
    private var wordsColumn: some View {
        VStack(spacing: 12) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                    words
                }
            }
            buttons
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(width: Self.wordsWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.page.ignoresSafeArea(edges: .vertical))
        .tint(Palette.nightGreen)
    }

    @ViewBuilder private var words: some View {
        if page.pasted == nil {
            Picker(selection: $page.mode) {
                Text("Live Text", bundle: .module).tag(Mode.liveText)
                Text("Vision", bundle: .module).tag(Mode.vision)
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
    }

    @ViewBuilder private var buttons: some View {
        if still == nil, page.pasted == nil {
            CameraButtons(
                picked: $picked, ready: camera.access == .ready,
                label: Text("Read the page", bundle: .module), freeze: takeStill,
                paste: paste)
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
            transcript
        }
    }

    /// The page on screen's text; nil until it is read.
    var currentTranscript: String? {
        if let pasted = page.pasted { return pasted }
        return text(of: currentPage, at: pages.count)
    }

    @ViewBuilder private var transcript: some View {
        if currentTranscript != nil {
            TranscriptReadout(pageTexts: pageTexts, selection: selection)
        } else if LiveText.isSupported {
            Text("Nothing was recognized.", bundle: .module)
                .foregroundStyle(.secondary)
        } else {
            Text("Live Text is not available on this device.", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }

    private func recognize() async {
        lines = []
        analysis = nil
        page.transcript = nil
        page.newPage(keepingFixes: !pages.isEmpty)
        selection.clear()
        selection.pageTexts[pages.count] = nil
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
        // The demo's pick, found again in the text as recognized: the reading keeps a
        // selection that stands when it is made, and the picture shows it.
        if let pick = DemoMode.pick, let found = Spread.join(pageTexts).range(of: pick) {
            let text = Spread.join(pageTexts)
            let start = text.distance(from: text.startIndex, to: found.lowerBound)
            page.selectedRange = start..<(start + pick.count)
        }
        AccessibilityNotification.Announcement(String(localized: "Page read", bundle: .module))
            .post()
    }
}
