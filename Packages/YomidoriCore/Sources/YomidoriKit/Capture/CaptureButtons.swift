import PhotosUI
import SwiftUI

struct CameraButtons: View {
    @Binding var picked: PhotosPickerItem?
    let ready: Bool
    let shutter: () -> Void

    var body: some View {
        HStack {
            PhotosPicker(selection: $picked, matching: .images) {
                Label {
                    Text("Choose a photo", bundle: .module)
                } icon: {
                    Image(systemName: "photo.on.rectangle")
                }
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .frame(maxWidth: .infinity)
            Button(action: shutter) {
                Circle()
                    .strokeBorder(Palette.nightGreen, lineWidth: 4)
                    .background(Circle().fill(.white))
                    .frame(width: 72, height: 72)
            }
            .accessibilityLabel(Text("Shutter", bundle: .module))
            .disabled(!ready)
            .opacity(ready ? 1 : 0.4)
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
    }
}
