import SwiftUI
import YomidoriCore

/// Where the app opens: the name, the way to the camera, and what study is waiting.
struct HomeView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var wordmark: CGFloat = 40
    let read: () -> Void
    /// Review and the lesson open on the Study tab, where they live, not over Home.
    let study: (Screen) -> Void
    @State private var dueCount = 0
    @State private var waitingCount = 0

    var body: some View {
        // Nothing scrolls: the bird up top, the name under it, and the buttons down where
        // the thumb is, just over the tab bar.
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            VStack(spacing: 12) {
                bird
                Wordmark(size: wordmark)
                Wordmark.reading
            }
            Spacer(minLength: 16)
            VStack(spacing: 12) {
                // Not a Label: it would drop its icon in some containers and leave its
                // title off center.
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
                HStack(spacing: 12) {
                    Button {
                        study(.review)
                    } label: {
                        StudyButtons.review(due: dueCount)
                    }
                    .buttonStyle(FatButtonStyle(color: StudyButtons.reviewColor))
                    .disabled(dueCount == 0)
                    Button {
                        study(.lesson)
                    } label: {
                        StudyButtons.lesson(waiting: waitingCount)
                    }
                    .buttonStyle(FatButtonStyle(color: StudyButtons.lessonColor))
                    .disabled(waitingCount == 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .readingWidth()
        .frame(maxHeight: .infinity)
        .background(Palette.page.ignoresSafeArea())
        .tint(Palette.nightGreen)
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
        .onAppear(perform: reload)
        .onReceive(Cards.changes(of: [.card])) { _ in reload() }
    }

    /// The bird itself, big, on a faint round of its green so its white cheeks have an
    /// edge against the page; the plate stays on the icon.
    private var bird: some View {
        Image("Bird", bundle: .main)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .padding(16)
            .background(Circle().fill(Palette.nightGreen.opacity(0.12)))
            .frame(maxWidth: 320, maxHeight: 320)
            .accessibilityHidden(true)
    }

    private func reload() {
        dueCount = Cards.dueItems(at: Date()).count
        waitingCount = Cards.store?.waiting().count ?? 0
    }
}
