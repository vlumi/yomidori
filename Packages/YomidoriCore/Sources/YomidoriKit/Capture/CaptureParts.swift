import SwiftUI
import YomidoriCore

extension CaptureView {
    enum Engine: Hashable {
        case vision
        case liveText
        case closeUp
    }

    /// One reading up close: the square around a tap, and what each engine made of it.
    struct Page {
        let still: Still
        let transcript: String
    }

    struct CloseUp {
        let box: CGRect
        let crop: Still
        let vision: String
        let liveText: String
    }
}

/// While a spread is open, the camera is for its next page.
struct SpreadNotice: View {
    let startOver: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Text("Take the next page, or start over.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Palette.silver)
                Button {
                    startOver()
                } label: {
                    Text("Start over", bundle: .module)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, 16)
        }
    }
}

/// Why there is no live image: no camera here, or no permission.
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
