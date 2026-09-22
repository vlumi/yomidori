import PhotosUI
import SwiftUI

struct CameraButtons: View {
    @Binding var picked: PhotosPickerItem?
    let ready: Bool
    let label: Text
    let freeze: () -> Void

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
            Button(action: freeze) {
                Label {
                    label
                } icon: {
                    Image(systemName: "text.viewfinder")
                }
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Palette.nightGreen)
            .disabled(!ready)
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
    }
}
