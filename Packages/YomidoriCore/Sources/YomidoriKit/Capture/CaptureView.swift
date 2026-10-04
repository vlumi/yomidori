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
    @State private var dropping = false
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

    /// The words column's width when the page stands beside it, as the reader last dragged
    /// it; while the camera is up the column holds only the buttons and takes less.
    @AppStorage(SettingsKey.wordsColumnWidth) private var wordsWidth: Double = 440
    @State private var wordsWidthAtDragStart: Double?
    static let narrowestWordsColumn: Double = 300
    static let buttonsColumnWidth: Double = 240

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
            // One layout whichever way the screen lies, so the page pane keeps its identity
            // across a turn: a camera preview made anew on every rotation is what made
            // turning an iPad slow. Room beside the page, an iPad on its side: the words in a
            // column of their own, as on the Mac, and no drawer.
            let columns = columns(in: geometry.size)
            let layout =
                columns
                ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(ZStackLayout(alignment: .bottom))
            layout {
                pagePane(in: pageArea(in: geometry.size), columns: columns)
                if columns {
                    wordsColumn(in: geometry.size)
                } else {
                    drawer(screenHeight: geometry.size.height)
                }
            }
            // The page being read, said over the whole screen — the picture and the words'
            // place alike — so a wait of a second or two reads as the app at work and not
            // as the app stuck; the picture still zooms and pans under it.
            .overlay {
                if let busy {
                    ZStack {
                        Color.black.opacity(0.35)
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                            busy
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: busy == nil)
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

    /// What the app is at while a page is on its way to its words: the recognizers, then
    /// the reading of the words; nil once the words are there, or when there is no page.
    private var busy: Text? {
        if recognizing { return Text("Reading the page…", bundle: .module) }
        if currentTranscript != nil, page.reading == nil {
            return Text("Reading the words…", bundle: .module)
        }
        return nil
    }

    /// The page's room: beside the words column, or above the drawer where it settled; while
    /// a drag is on, the drawer lies over the page or leaves a gap, and the page follows on
    /// release.
    private func pageArea(in screen: CGSize) -> CGSize {
        if columns(in: screen) {
            return CGSize(width: screen.width - columnWidth(in: screen), height: screen.height)
        }
        return CGSize(
            width: screen.width,
            height: screen.height
                - DrawerDetents.height(fraction: readoutFraction, screenHeight: screen.height))
    }

    /// The still, the pasted text or the camera, in its room, over black — which stays
    /// under the status bar on a phone, where the page is the whole screen, and not beside
    /// the sections' sidebar, where the bar's own color should hold.
    @ViewBuilder private func pagePane(in area: CGSize, columns: Bool) -> some View {
        ZStack {
            Color.black.ignoresSafeArea(edges: columns ? .bottom : .all)
            if let still {
                stillView(still, in: area)
            } else if let pasted = page.pasted {
                TextPage(text: pasted, selection: selection)
                    .frame(height: area.height)
                    // The camera button the picture has, so the hint under the words holds
                    // for a pasted page too.
                    .overlay(alignment: controlsSide.alignment) {
                        PageButton(
                            symbol: "camera", label: Text("Back to the camera", bundle: .module),
                            action: retake
                        )
                        .padding(12)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .onTabReselect(.read) { retake() }
            } else {
                cameraView
            }
        }
        // A picture dropped on the page from another app or Files, an iPad beside one; and
        // ⌘V from a keyboard, a picture or a text — the keystroke being the consent to read
        // the pasteboard, as the Paste button's tap is.
        .onDrop(of: [.image, .fileURL], isTargeted: $dropping) { providers in
            Still.take(from: providers, take)
        }
        .background {
            Button {
                pasteFromPasteboard()
            } label: {
                EmptyView()
            }
            .keyboardShortcut("v", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .overlay {
            if dropping {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Palette.nightGreen, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
    }

    private var cameraView: some View {
        ZStack {
            CameraPreview(camera: camera, access: camera.access, freeze: takeStill)
                .ignoresSafeArea()
            CameraNotice(access: camera.access)
            if !pages.isEmpty {
                SpreadNotice(backToPage: backToPage, startOver: startOver)
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
        .overlay(alignment: controlsSide.alignment) {
            PageControls(
                side: controlsSide, pageCount: pages.isEmpty ? nil : pages.count + 1,
                canAddPage: currentTranscript != nil && pages.count + 1 < Self.pagesInASpread,
                addPage: addPage, startOver: startOver, retake: retake,
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
            Text("The camera button takes a new page.", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private var buttons: some View {
        if still == nil, page.pasted == nil {
            CameraButtons(
                picked: $picked, ready: camera.access == .ready,
                label: Text("Read the page", bundle: .module), freeze: takeStill,
                paste: paste, take: take)
        }
    }

    @ViewBuilder private var readout: some View {
        if recognizing {
            VStack(spacing: 6) {
                ProgressView {
                    Text("Reading the page…", bundle: .module)
                }
                Text(
                    "Blurred or not quite framed? The camera button takes another photo.",
                    bundle: .module
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
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
        } else if still == nil, page.pasted == nil {
            // No page yet: nothing has failed.
            Text("Take a page, and its words read out here.", bundle: .module)
                .foregroundStyle(.secondary)
        } else if LiveText.isSupported {
            Text("Nothing was recognized.", bundle: .module)
                .foregroundStyle(.secondary)
        } else {
            Text("Live Text is not available on this device.", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: The page beside the words, an iPad on its side

extension CaptureView {
    /// A regular width lying down: the page and the words side by side.
    private func columns(in screen: CGSize) -> Bool {
        sizeClass == .regular && screen.width > screen.height
    }

    /// The words column's width for the screen: what the reader set, within a third and
    /// three fifths of the width; the buttons alone while the camera is up.
    private func columnWidth(in screen: CGSize) -> Double {
        if still == nil, page.pasted == nil { return Self.buttonsColumnWidth }
        return min(max(wordsWidth, Self.narrowestWordsColumn), screen.width * 0.6)
    }

    /// The words beside the page: what the drawer holds, standing, with the buttons under,
    /// and a handle on its left edge to drag it wider or narrower.
    private func wordsColumn(in screen: CGSize) -> some View {
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
        .frame(width: columnWidth(in: screen))
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.page.ignoresSafeArea(edges: .vertical))
        .tint(Palette.nightGreen)
        .overlay(alignment: .leading) {
            if still != nil || page.pasted != nil {
                Rectangle()
                    .fill(Palette.silver.opacity(0.35))
                    .frame(width: 1)
                    .frame(width: 16)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                let start = wordsWidthAtDragStart ?? wordsWidth
                                wordsWidthAtDragStart = start
                                wordsWidth = min(
                                    max(start - value.translation.width, Self.narrowestWordsColumn),
                                    screen.width * 0.6)
                            }
                            .onEnded { _ in wordsWidthAtDragStart = nil }
                    )
                    .accessibilityLabel(Text("Words column edge", bundle: .module))
                    .accessibilityHint(
                        Text("Drag to make the column wider or narrower", bundle: .module))
            }
        }
    }
}
