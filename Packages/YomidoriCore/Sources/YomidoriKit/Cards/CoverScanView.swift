import PhotosUI
import SwiftUI
import VisionKit
import YomidoriCore

/// A book cover through the camera or from the photos — on the Mac, from the photos, a file
/// or a drop: the picture becomes the collection's cover, and the words read off it are
/// offered for the name and the note, the largest print first, so a title need not be typed.
struct CoverScanView: View {
    @Binding var collection: Collection
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = Camera()
    @State private var still: Still?
    @State private var lines: [String] = []
    @State private var reading = false
    /// The cover being scaled and written, off the main thread; the button waits.
    @State private var keeping = false
    @State private var picked: PhotosPickerItem?
    @State private var opening = false
    @State private var dropping = false

    var body: some View {
        NavigationStack {
            Group {
                if let still {
                    read(still)
                } else {
                    #if os(macOS)
                    chooser
                    #else
                    ZStack {
                        Color.black.ignoresSafeArea()
                        CameraPreview(camera: camera, access: camera.access, freeze: takeStill)
                            .ignoresSafeArea()
                        CameraNotice(access: camera.access)
                    }
                    .safeAreaInset(edge: .bottom) {
                        CameraButtons(
                            picked: $picked, ready: camera.access == .ready,
                            label: Text("Scan the cover", bundle: .module), freeze: takeStill
                        )
                        .padding(16)
                        .background(Palette.page)
                    }
                    #endif
                }
            }
            .navigationTitle(Text("Cover", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", bundle: .module)
                    }
                }
                if still != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            keep()
                        } label: {
                            Text("Use", bundle: .module)
                        }
                        .disabled(keeping)
                    }
                }
            }
            .onAppear { camera.start() }
            .onDisappear { camera.stop() }
            .task(id: picked) { await loadPicked() }
            .task(id: still?.id) { await recognize() }
            .tint(Palette.nightGreen)
        }
    }

    private func read(_ still: Still) -> some View {
        List {
            picture(still)
            Section {
                TextField(text: $collection.name) {
                    Text("Name", bundle: .module)
                }
                TextField(text: $collection.note) {
                    Text("Note, an author say", bundle: .module)
                }
            }
            readLines
        }
    }

    private func picture(_ still: Still) -> some View {
        Section {
            Image(decorative: still.preview, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button {
                self.still = nil
                picked = nil
                camera.start()
            } label: {
                #if os(macOS)
                Label {
                    Text("Another picture", bundle: .module)
                } icon: {
                    Image(systemName: "photo.on.rectangle")
                }
                #else
                Label {
                    Text("Retake", bundle: .module)
                } icon: {
                    Image(systemName: "camera")
                }
                #endif
            }
        }
    }

    private var readLines: some View {
        Section {
            if reading {
                ProgressView()
            } else if lines.isEmpty {
                Text("Nothing was read off the cover.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            // By place: a title printed twice is read twice.
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                FitsOrStacks {
                    Text(japanese: line)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        collection.name = line
                    } label: {
                        Text("Name", bundle: .module)
                    }
                    Button {
                        collection.note = line
                    } label: {
                        Text("Note", bundle: .module)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } header: {
            Text("Read off the cover", bundle: .module)
        }
    }

    #if os(macOS)
    /// No camera on the Mac: the photos, a file, or a picture dropped in.
    private var chooser: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Drop a picture of the cover here, or choose one.", bundle: .module)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                PhotosPicker(selection: $picked, matching: .images) {
                    Text("From Photos…", bundle: .module)
                }
                Button {
                    opening = true
                } label: {
                    Text("From a file…", bundle: .module)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .overlay {
            if dropping {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Palette.nightGreen, lineWidth: 3)
                    .padding(6)
            }
        }
        .onDrop(of: [.image, .fileURL], isTargeted: $dropping) { providers in
            Still.take(from: providers) { still = $0 }
        }
        .fileImporter(isPresented: $opening, allowedContentTypes: [.image]) { result in
            Still.take(picked: result) { still = $0 }
        }
    }
    #endif

    private func takeStill() {
        Task { @MainActor in
            if let taken = await camera.takeStill() {
                camera.stop()
                still = taken
            }
        }
    }

    private func loadPicked() async {
        guard let picked, let data = try? await picked.loadTransferable(type: Data.self),
            let loaded = await Task.detached(priority: .userInitiated) { Still(data: data) }.value,
            !Task.isCancelled
        else { return }
        camera.stop()
        still = loaded
    }

    private func recognize() async {
        lines = []
        guard let still else { return }
        reading = true
        let read = await PageRecognition.read(still)
        guard !Task.isCancelled else { return }
        lines = CoverLines.merge(vision: read.lines, liveText: read.analysis?.transcript)
        reading = false
    }

    /// The still scaled to a cover and written, off the main thread — a 48-megapixel still
    /// drawn down is a visible pause — then the collection takes it and the sheet goes.
    private func keep() {
        guard let still, !keeping else { return }
        keeping = true
        let image = still.image
        Task {
            let id = await Task.detached(priority: .userInitiated) {
                try? CoverArchive.save(image)
            }.value
            if let id { collection.coverID = id }
            dismiss()
        }
    }
}
