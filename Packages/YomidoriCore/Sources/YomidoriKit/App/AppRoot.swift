import Combine
import SwiftUI
import YomidoriCore

public enum AppTab: String, Sendable {
    case home
    case read
    case study
    case cards
    case search
}

/// Home, the camera, study, the cards, and search as its own pill. Each tab has its own
/// stack; the home stack's path is kept across a restart so the app reopens where it was.
/// Tapping the tab already showing pops its stack and scrolls its list to the top.
public struct AppRoot: View {
    @SceneStorage("tab") private var tab: AppTab = .home
    @StateObject private var capture = CaptureState()
    @StateObject private var taps = TabTaps()
    @State private var dueCount = 0
    @State private var imported: CollectionImport?
    @State private var importFailed = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass

    public init() {}

    public var body: some View {
        TabView(selection: selection) {
            // On a Mac, Read is the home: the text box, with Settings and About in the
            // app's own menus.
            #if os(iOS)
            Tab(value: .home) {
                TabStack(tab: .home, stored: true) {
                    HomeView(
                        read: { tab = .read },
                        study: { screen in
                            taps.open(screen, in: .study)
                            tab = .study
                        })
                }
            } label: {
                Label {
                    Text("Home", bundle: .module)
                } icon: {
                    Image(systemName: "house")
                }
            }
            Tab(value: .read) {
                TabStack(tab: .read) { CaptureView().clearNavigationBar() }
            } label: {
                Label {
                    Text("Read", bundle: .module)
                } icon: {
                    Image(systemName: "camera.viewfinder")
                }
            }
            #else
            Tab(value: .read) {
                TabStack(tab: .read, stored: true) { MacReadView() }
            } label: {
                Label {
                    Text("Read", bundle: .module)
                } icon: {
                    Image(systemName: "text.page")
                }
            }
            #endif
            Tab(value: .study) {
                TabStack(tab: .study) { StudyView() }
            } label: {
                Label {
                    Text("Study", bundle: .module)
                } icon: {
                    Image(systemName: "checkmark.rectangle.stack")
                }
            }
            .badge(dueCount)
            // Cards and the dictionary are splits where there is room — the Mac, an iPad
            // in a regular width — with a stack of their own in the detail column; a stack
            // over a split is not had, so they get no TabStack there.
            Tab(value: .cards) {
                #if os(macOS)
                CardsView()
                #else
                if sizeClass == .regular {
                    CardsView()
                } else {
                    TabStack(tab: .cards) { CardsView() }
                }
                #endif
            } label: {
                Label {
                    Text("Cards", bundle: .module)
                } icon: {
                    Image(systemName: "rectangle.stack")
                }
            }
            Tab(value: .search, role: .search) {
                #if os(macOS)
                SearchView()
                #else
                if sizeClass == .regular {
                    SearchView()
                } else {
                    TabStack(tab: .search) { SearchView() }
                }
                #endif
            } label: {
                Label {
                    Text("Dictionary", bundle: .module)
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .minimizingTabBarOnScroll()
        // A sidebar where there is room, an iPad on its side or a Mac window; the phone's
        // bar in a compact width. SectionCommands gives the sections their ⌘ keys.
        .tabViewStyle(.sidebarAdaptable)
        .chosenAppearance()
        .tint(Palette.nightGreen)
        .environmentObject(capture)
        .environmentObject(taps)
        .onReceive(AppCommands.shared.$requestedTab.compactMap { $0 }) { asked in
            tab = asked
            AppCommands.shared.requestedTab = nil
        }
        .onAppear {
            if DemoMode.isRequested { DemoData.seed(capture) }
            if let shown = DemoMode.tab {
                tab = shown
                // Once more after the scene's own restoring, which on the Mac comes later
                // and would put back the tab the last run was left on.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    tab = shown
                }
            }
            #if os(macOS)
            if tab == .home { tab = .read }
            #endif
        }
        .task(id: tab) { dueCount = Cards.dueItems(at: Date()).count }
        .onOpenURL { url in
            Task {
                if let done = try? await Cards.importCollection(from: url) {
                    imported = done
                    tab = .cards
                } else {
                    importFailed = true
                }
            }
        }
        .collectionImportAlerts(imported: $imported, failed: $importFailed)
        // An image from outside, a shortcut's screenshot: a new page on the Read tab.
        .onReceive(StillInbox.shared.$arrival.compactMap { $0 }) { still in
            capture.clearPage()
            capture.still = still
            tab = .read
            StillInbox.shared.clear()
        }
        .task {
            Sync.shared.start()
            AppBadge.refresh()
            Warmup.start()
        }
        .onChange(of: tab, initial: true) { _, shown in taps.shown = shown }
        .onChange(of: scenePhase) { _, phase in
            // Started here too, so signing in to iCloud while away starts sync on return.
            if phase == .active {
                Sync.shared.start()
                Sync.shared.fetch()
                Cards.snapshotRanks()
            }
            // Leaving, the icon's count is set for the hours the app is away.
            if phase == .background { AppBadge.refresh() }
        }
        .onReceive(Cards.changes(of: [.card])) { _ in
            dueCount = Cards.dueItems(at: Date()).count
            AppBadge.refresh()
        }
    }

    /// The tab, and a tap on the one already showing, which the binding sees as a set to
    /// the same value.
    private var selection: Binding<AppTab> {
        Binding {
            tab
        } set: { chosen in
            if chosen == tab { taps.tapped(chosen) } else { tab = chosen }
        }
    }
}

/// One tab's navigation stack: pops to its root when the tab is tapped again, and for the
/// home tab stores its path so a restart returns to the same screen.
private struct TabStack<Root: View>: View {
    let tab: AppTab
    var stored = false
    @ViewBuilder let root: () -> Root
    @State private var path = NavigationPath()
    @SceneStorage private var storedPath: Data?
    @EnvironmentObject private var taps: TabTaps

    init(tab: AppTab, stored: Bool = false, @ViewBuilder root: @escaping () -> Root) {
        self.tab = tab
        self.stored = stored
        self.root = root
        // The home tab's path under the key it has always had; any other tab's under its own,
        // so two tabs never restore each other's screens.
        _storedPath = SceneStorage(
            tab == .home ? "navigationPath" : "navigationPath.\(tab.rawValue)")
    }

    var body: some View {
        NavigationStack(path: $path) {
            root().swipeBackSetting().appDestinations()
        }
        .onTabTap(tab) { taps in
            if path.isEmpty { taps.tappedAtRoot(tab) } else { path = NavigationPath() }
        }
        // A screen asked for on this tab from another; `initial` for a stack made by the
        // switch itself, after the ask.
        .onChange(of: taps.opening, initial: true) { _, opening in
            guard let opening, opening.tab == tab else { return }
            path = NavigationPath()
            path.append(opening.screen)
            taps.opening = nil
        }
        .onAppear {
            if stored { restore() }
            if let screen = DemoMode.screen, DemoMode.tab == tab, path.isEmpty {
                path.append(screen)
            }
        }
        .task(id: path) { if stored { store() } }
    }

    private func restore() {
        guard let storedPath,
            let representation = try? JSONDecoder().decode(
                NavigationPath.CodableRepresentation.self, from: storedPath)
        else { return }
        path = NavigationPath(representation)
    }

    private func store() {
        guard let codable = path.codable else { return }
        storedPath = try? JSONEncoder().encode(codable)
    }
}
