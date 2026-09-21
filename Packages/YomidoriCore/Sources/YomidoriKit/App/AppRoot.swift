import SwiftUI
import YomidoriCore

public struct AppRoot: View {
    @State private var path = NavigationPath()
    @StateObject private var capture = CaptureState()
    @SceneStorage("navigationPath") private var storedPath: Data?

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .capture:
                        CaptureView().clearNavigationBar()
                    case .cards:
                        CardsView()
                    case .review:
                        ReviewView()
                    case .search:
                        SearchView()
                    case .about:
                        AboutView()
                    }
                }
                .navigationDestination(for: Card.self) { card in
                    CardView(card: card)
                }
                .navigationDestination(for: DictionaryEntry.self) { entry in
                    EntryView(entry: entry)
                }
                .navigationDestination(for: KanjiEntry.self) { kanji in
                    KanjiView(kanji: kanji)
                }
        }
        .tint(Palette.nightGreen)
        .environmentObject(capture)
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
