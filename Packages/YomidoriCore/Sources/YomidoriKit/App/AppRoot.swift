import SwiftUI
import YomidoriCore

/// The root: home, with the screens a push away, and the path kept across a
/// restart so the app reopens where it was left, the camera included.
public struct AppRoot: View {
    @State private var path = NavigationPath()
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
                    case .about:
                        AboutView()
                    }
                }
                .navigationDestination(for: Card.self) { card in
                    CardView(card: card)
                }
        }
        .tint(Palette.nightGreen)
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
