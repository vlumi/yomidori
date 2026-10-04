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
            .navigationDestination(for: Collection.self) { collection in
                CollectionEditor(collection: collection)
            }
    }
}

extension View {
    func appDestinations() -> some View {
        modifier(Destinations())
    }
}
