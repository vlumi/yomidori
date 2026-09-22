import SwiftUI
import YomidoriCore

/// Where the app opens: the name, the way to the camera, and what study is waiting.
struct HomeView: View {
    let read: () -> Void
    @State private var dueCount = 0
    @State private var waitingCount = 0

    var body: some View {
        ScrollViewReader { proxy in
            list.scrollsToTopOnReselect(of: .home, with: proxy)
        }
    }

    private var list: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    Text(verbatim: "ヨミドリ")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.nightGreen)
                    Text(verbatim: Kana.hiragana("ヨミドリ"))
                        .font(.callout)
                        .foregroundStyle(Palette.silver)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }
            .id(TabTop.id)
            Section {
                // Not a Label: a list row drops a label's icon and leaves its title off center.
                Button(action: read) {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                        Text("Read", bundle: .module)
                    }
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                if dueCount > 0 {
                    NavigationLink(value: Screen.review) {
                        Label {
                            Text("Review \(dueCount)", bundle: .module)
                        } icon: {
                            Image(systemName: "checkmark.rectangle.stack")
                        }
                    }
                } else {
                    Text("Nothing due. Read on.", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                if waitingCount > 0 {
                    NavigationLink(value: Screen.lesson) {
                        Label {
                            Text("Lesson · \(waitingCount) waiting", bundle: .module)
                        } icon: {
                            Image(systemName: "book")
                        }
                    }
                }
            } header: {
                Text("Study", bundle: .module)
            }
        }
        .navigationTitle(Text(verbatim: ""))
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
        .onAppear {
            dueCount = Cards.dueItems(at: Date()).count
            waitingCount = Cards.store?.waiting().count ?? 0
        }
    }
}
