import SwiftUI
import YomidoriCore

/// The one screen there is so far: the name, until the camera view replaces it.
public struct AppRoot: View {
    public init() {}

    public var body: some View {
        ZStack {
            Palette.page.ignoresSafeArea()
            VStack(spacing: 12) {
                Text(verbatim: "ヨミドリ")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.nightGreen)
                Text(verbatim: Kana.hiragana("ヨミドリ"))
                    .font(.title3)
                    .foregroundStyle(Palette.silver)
                Text("Point at a word, get its reading.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }
}
