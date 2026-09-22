import SwiftUI
import YomidoriCore

enum AppTab: String {
    case home
    case cards
    case search
}

/// Three tabs: home with the camera a push away, the cards, and search as its own pill on
/// iOS 26. The home stack's path is kept across a restart so the app reopens where it was.
public struct AppRoot: View {
    @SceneStorage("tab") private var tab: AppTab = .home
    @StateObject private var capture = CaptureState()
    @State private var dueCount = 0

    public init() {}

    public var body: some View {
        Group {
            if #available(iOS 18, macOS 15, *) {
                TabView(selection: $tab) {
                    Tab(value: .home) {
                        HomeStack()
                    } label: {
                        Label {
                            Text("Home", bundle: .module)
                        } icon: {
                            Image(systemName: "book")
                        }
                    }
                    Tab(value: .cards) {
                        cardsStack
                    } label: {
                        Label {
                            Text("Cards", bundle: .module)
                        } icon: {
                            Image(systemName: "rectangle.stack")
                        }
                    }
                    .badge(dueCount)
                    Tab(value: .search, role: .search) {
                        searchStack
                    }
                }
            } else {
                TabView(selection: $tab) {
                    HomeStack()
                        .tabItem {
                            Label {
                                Text("Home", bundle: .module)
                            } icon: {
                                Image(systemName: "book")
                            }
                        }
                        .tag(AppTab.home)
                    cardsStack
                        .tabItem {
                            Label {
                                Text("Cards", bundle: .module)
                            } icon: {
                                Image(systemName: "rectangle.stack")
                            }
                        }
                        .badge(dueCount)
                        .tag(AppTab.cards)
                    searchStack
                        .tabItem {
                            Label {
                                Text("Search", bundle: .module)
                            } icon: {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                        .tag(AppTab.search)
                }
            }
        }
        .tint(Palette.nightGreen)
        .environmentObject(capture)
        .task(id: tab) { countDue() }
    }

    private var cardsStack: some View {
        NavigationStack {
            CardsView().swipeBackSetting().appDestinations()
        }
    }

    private var searchStack: some View {
        NavigationStack {
            SearchView().swipeBackSetting().appDestinations()
        }
    }

    private func countDue() {
        dueCount = Cards.dueItems(at: Date()).count
    }
}

/// The home tab's own stack, its path stored so a restart returns to the same screen.
private struct HomeStack: View {
    @State private var path = NavigationPath()
    @SceneStorage("navigationPath") private var storedPath: Data?

    var body: some View {
        NavigationStack(path: $path) {
            HomeView().swipeBackSetting().appDestinations()
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
