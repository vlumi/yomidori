import SwiftUI
import YomidoriCore

enum AppTab: String {
    case home
    case read
    case study
    case cards
    case search
}

/// Home, the camera, study, the cards, and search as its own pill. The home stack's path is
/// kept across a restart so the app reopens where it was.
public struct AppRoot: View {
    @SceneStorage("tab") private var tab: AppTab = .home
    @StateObject private var capture = CaptureState()
    @State private var dueCount = 0

    public init() {}

    public var body: some View {
        TabView(selection: $tab) {
            Tab(value: .home) {
                HomeStack(tab: $tab)
            } label: {
                Label {
                    Text("Home", bundle: .module)
                } icon: {
                    Image(systemName: "house")
                }
            }
            Tab(value: .read) {
                NavigationStack {
                    CaptureView().clearNavigationBar().swipeBackSetting().appDestinations()
                }
            } label: {
                Label {
                    Text("Read", bundle: .module)
                } icon: {
                    Image(systemName: "camera.viewfinder")
                }
            }
            Tab(value: .study) {
                NavigationStack {
                    StudyView().swipeBackSetting().appDestinations()
                }
            } label: {
                Label {
                    Text("Study", bundle: .module)
                } icon: {
                    Image(systemName: "checkmark.rectangle.stack")
                }
            }
            .badge(dueCount)
            Tab(value: .cards) {
                NavigationStack {
                    CardsView().swipeBackSetting().appDestinations()
                }
            } label: {
                Label {
                    Text("Cards", bundle: .module)
                } icon: {
                    Image(systemName: "rectangle.stack")
                }
            }
            Tab(value: .search, role: .search) {
                NavigationStack {
                    SearchView().swipeBackSetting().appDestinations()
                }
            }
        }
        .minimizingTabBarOnScroll()
        .tint(Palette.nightGreen)
        .environmentObject(capture)
        .task(id: tab) { dueCount = Cards.dueItems(at: Date()).count }
    }
}

/// The home tab's own stack, its path stored so a restart returns to the same screen.
private struct HomeStack: View {
    @Binding var tab: AppTab
    @State private var path = NavigationPath()
    @SceneStorage("navigationPath") private var storedPath: Data?

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(read: { tab = .read }).swipeBackSetting().appDestinations()
        }
        .onAppear(perform: restore)
        .task(id: path) { store() }
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
