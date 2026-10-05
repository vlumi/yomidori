import SwiftUI

/// Which side of the page its controls stand on, for the hand that holds the phone.
enum PageControlsSide: String, CaseIterable {
    case left
    case right

    var alignment: Alignment { self == .left ? .bottomLeading : .bottomTrailing }
    var horizontal: HorizontalAlignment { self == .left ? .leading : .trailing }
}

/// Everything done to the page, in one column on the chosen side: the spread's way out on
/// top, the next page, then the camera for another photo and the zoom at the bottom — the
/// two used most, nearest the thumb.
struct PageControls: View {
    let side: PageControlsSide
    /// The page's number in a spread; nil for a single page.
    let pageCount: Int?
    let canAddPage: Bool
    let addPage: () -> Void
    let startOver: () -> Void
    /// Back to the camera for another photo, the page let go.
    let retake: () -> Void
    /// Moves the second page round the first; nil until there is a second page.
    var moveNextPage: (() -> Void)?
    @Binding var zoom: Double
    var showsZoom = true

    /// Three buttons, their gaps, the slider at its shortest and the padding round them.
    static let heightWithZoom: CGFloat = 3 * 44 + 3 * 14 + 60 + 24

    var body: some View {
        VStack(alignment: side.horizontal, spacing: 14) {
            if let pageCount {
                StartOverButton(pageCount: pageCount, action: startOver)
            }
            if let moveNextPage {
                PageButton(
                    symbol: "rectangle.2.swap",
                    label: Text("Move the second page", bundle: .module), action: moveNextPage)
            } else {
                PageButton(
                    symbol: "plus", label: Text("Add next page", bundle: .module), action: addPage
                )
                .disabled(!canAddPage)
            }
            PageButton(
                symbol: "camera", label: Text("Take another photo", bundle: .module),
                action: retake)
            if showsZoom {
                ZoomSlider(fraction: $zoom)
            }
        }
    }
}
