import SwiftUI
import YomidoriKit

@main
struct YomidoriApp: App {
    var body: some Scene {
        WindowGroup {
            AppRoot()
                .defaultAppStorage(DemoMode.defaults ?? .standard)
        }
    }
}
