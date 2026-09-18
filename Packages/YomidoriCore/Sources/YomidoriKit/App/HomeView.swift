import SwiftUI
import YomidoriCore

/// Where the app opens on a fresh start: the name, one big button to read, the
/// cards with what is due, and About below. The camera waits until asked.
struct HomeView: View {
    @State private var dueCount = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 8) {
                Text(verbatim: "ヨミドリ")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.nightGreen)
                Text(verbatim: Kana.hiragana("ヨミドリ"))
                    .font(.title3)
                    .foregroundStyle(Palette.silver)
                Text("Point at a word, get its reading.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            Spacer()
            VStack(spacing: 14) {
                NavigationLink(value: Screen.capture) {
                    Label {
                        Text("Read", bundle: .module)
                    } icon: {
                        Image(systemName: "camera.viewfinder")
                    }
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                NavigationLink(value: Screen.cards) {
                    HStack {
                        Label {
                            Text("Cards", bundle: .module)
                        } icon: {
                            Image(systemName: "rectangle.stack")
                        }
                        Spacer()
                        if dueCount > 0 {
                            Text("Review \(dueCount)", bundle: .module)
                                .foregroundStyle(Palette.nightGreen)
                        }
                    }
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                NavigationLink(value: Screen.search) {
                    Label {
                        Text("Search", bundle: .module)
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                NavigationLink(value: Screen.about) {
                    Text("About", bundle: .module)
                        .font(.callout)
                }
                .padding(.top, 8)
            }
            .controlSize(.large)
            .tint(Palette.nightGreen)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Palette.page.ignoresSafeArea())
        .onAppear { dueCount = Cards.store?.dueItems(at: Date()).count ?? 0 }
    }
}

/// The screens a push away from home. Codable, so the path survives a restart.
enum Screen: Hashable, Codable {
    case capture
    case cards
    case review
    case search
    case about
}
