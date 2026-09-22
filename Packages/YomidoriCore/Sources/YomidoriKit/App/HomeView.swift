import SwiftUI
import YomidoriCore

struct HomeView: View {
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
            .controlSize(.large)
            .tint(Palette.nightGreen)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Palette.page.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink(value: Screen.settings) {
                    Label {
                        Text("Settings", bundle: .module)
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
                NavigationLink(value: Screen.about) {
                    Label {
                        Text("About", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
    }
}

enum Screen: Hashable, Codable {
    case capture
    case cards
    case review
    case search
    case about
    case settings
}
