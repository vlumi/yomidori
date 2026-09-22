import SwiftUI
import YomidoriCore

enum AppTab: String {
    case read
    case cards
    case search
}

/// Three tabs: the camera first, the cards as the landing tab, and search as its own pill.
/// The cards stack's path is kept across a restart so the app reopens where it was.
public struct AppRoot: View {
    @SceneStorage("tab") private var tab: AppTab = .cards
    @StateObject private var capture = CaptureState()
    @State private var dueCount = 0

    public init() {}

    public var body: some View {
        TabView(selection: $tab) {
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
            Tab(value: .cards) {
                CardsStack()
            } label: {
                Label {
                    Text("Cards", bundle: .module)
                } icon: {
                    Image(systemName: "rectangle.stack")
                }
            }
            .badge(dueCount)
            Tab(value: .search, role: .search) {
                NavigationStack {
                    SearchView().swipeBackSetting().appDestinations()
                }
            }
        }
        .tint(Palette.nightGreen)
        .environmentObject(capture)
        .task(id: tab) { dueCount = Cards.dueItems(at: Date()).count }
    }
}

/// The cards tab's own stack, its path stored so a restart returns to the same screen.
private struct CardsStack: View {
    @State private var path = NavigationPath()
    @SceneStorage("navigationPath") private var storedPath: Data?

    var body: some View {
        NavigationStack(path: $path) {
            CardsView().swipeBackSetting().appDestinations()
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
