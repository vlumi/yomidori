import SwiftUI
import YomidoriCore

/// Every screen a push can reach, registered once per navigation stack.
struct Destinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Screen.self) { screen in
                Group {
                    switch screen {
                    case .review:
                        ReviewView()
                    case .about:
                        AboutView()
                    case .settings:
                        SettingsView()
                    case .lesson:
                        LessonView()
                    case .collections:
                        CollectionsView()
                    case .progress:
                        ProgressScreen()
                    case .practice(let cards):
                        ReviewView(practicing: Set(cards))
                    }
                }
                .columnTitle()
            }
            .navigationDestination(for: Card.self) { card in
                CardView(card: card).columnTitle()
            }
            .navigationDestination(for: DictionaryEntry.self) { entry in
                EntryView(entry: entry).columnTitle()
            }
            .navigationDestination(for: KanjiEntry.self) { kanji in
                KanjiView(kanji: kanji).columnTitle()
            }
            .navigationDestination(for: Collection.self) { collection in
                CollectionEditor(collection: collection).columnTitle()
            }
    }
}

extension View {
    func appDestinations() -> some View {
        modifier(Destinations())
    }
}
