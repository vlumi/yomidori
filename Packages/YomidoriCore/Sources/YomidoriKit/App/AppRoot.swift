import Combine
import SwiftUI
import YomidoriCore

enum AppTab: String {
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

    public init() {}

    public var body: some View {
        TabView(selection: selection) {
            Tab(value: .home) {
                TabStack(tab: .home, stored: true) { HomeView(read: { tab = .read }) }
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
            Tab(value: .cards) {
                TabStack(tab: .cards) { CardsView() }
            } label: {
                Label {
                    Text("Cards", bundle: .module)
                } icon: {
                    Image(systemName: "rectangle.stack")
                }
            }
            Tab(value: .search, role: .search) {
                TabStack(tab: .search) { SearchView() }
            }
        }
        .minimizingTabBarOnScroll()
        .tint(Palette.nightGreen)
        .environmentObject(capture)
        .environmentObject(taps)
        .onAppear {
            if DemoMode.isRequested { DemoData.seed(capture) }
            if let shown = DemoMode.tab { tab = shown }
        }
        .task(id: tab) { dueCount = Cards.dueItems(at: Date()).count }
        .onOpenURL { url in
            if let done = try? Cards.importCollection(from: url) {
                imported = done
                tab = .cards
            } else {
                importFailed = true
            }
        }
        .collectionImportAlerts(imported: $imported, failed: $importFailed)
        .task { Sync.shared.start() }
        .onChange(of: tab, initial: true) { _, shown in taps.shown = shown }
        .onChange(of: scenePhase) { _, phase in
            // Started here too, so signing in to iCloud while away starts sync on return.
            if phase == .active {
                Sync.shared.start()
                Sync.shared.fetch()
            }
        }
        .onReceive(Cards.changes(of: [.card])) { _ in
            dueCount = Cards.dueItems(at: Date()).count
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
    @SceneStorage("navigationPath") private var storedPath: Data?

    var body: some View {
        NavigationStack(path: $path) {
            root().swipeBackSetting().appDestinations()
        }
        .onTabTap(tab) { taps in
            if path.isEmpty { taps.tappedAtRoot(tab) } else { path = NavigationPath() }
        }
        .onAppear { if stored { restore() } }
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
