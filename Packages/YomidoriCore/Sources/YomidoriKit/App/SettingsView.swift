import SwiftUI

struct SettingsView: View {
    @AppStorage(SwipeBack.key) private var swipeBack = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $swipeBack) {
                    Text("Swipe back", bundle: .module)
                }
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "Swiping in from the left edge goes back a screen, as everywhere on iOS. Off, only the back button does, so a swipe meant for a word never leaves the page.",
                    bundle: .module)
            }
        }
        .tint(Palette.nightGreen)
        .navigationTitle(Text("Settings", bundle: .module))
    }
}
