import SwiftUI

/// The root: the capture screen, with the cards a push away.
public struct AppRoot: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            CaptureView()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            CardsView()
                        } label: {
                            Label {
                                Text("Cards", bundle: .module)
                            } icon: {
                                Image(systemName: "rectangle.stack")
                            }
                        }
                    }
                }
                .clearNavigationBar()
                .tint(Palette.nightGreen)
        }
    }
}
