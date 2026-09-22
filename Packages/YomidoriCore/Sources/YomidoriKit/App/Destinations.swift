import SwiftUI
import YomidoriCore

/// Every screen a push can reach, registered once per navigation stack.
struct Destinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Screen.self) { screen in
                Group {
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
                    case .settings:
                        SettingsView()
                    }
                }
                .swipeBackSetting()
            }
            .navigationDestination(for: Card.self) { card in
                CardView(card: card).swipeBackSetting()
            }
            .navigationDestination(for: DictionaryEntry.self) { entry in
                EntryView(entry: entry).swipeBackSetting()
            }
            .navigationDestination(for: KanjiEntry.self) { kanji in
                KanjiView(kanji: kanji).swipeBackSetting()
            }
    }
}

extension View {
    func appDestinations() -> some View {
        modifier(Destinations())
    }
}
