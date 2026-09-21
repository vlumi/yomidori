import SwiftUI

struct CameraNotice: View {
    let access: Camera.Access

    var body: some View {
        switch access {
        case .denied:
            notice("Camera access is off. Turn it on in Settings to frame a page.")
        case .unavailable:
            notice("No camera here. Choose a photo instead.")
        case .undetermined, .ready:
            EmptyView()
        }
    }

    private func notice(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: .module)
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.silver)
            .padding(24)
    }
}
