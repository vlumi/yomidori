import SwiftUI

/// Which side of the page its controls stand on, for the hand that holds the phone.
enum PageControlsSide: String, CaseIterable {
    case left
    case right

    var alignment: Alignment { self == .left ? .bottomLeading : .bottomTrailing }
    var horizontal: HorizontalAlignment { self == .left ? .leading : .trailing }
}

/// Everything done to the page, in one column on the chosen side: the spread's way out on
/// top, the next page, then the camera for another photo and the zoom at the bottom. On a
/// phone the camera and the next page stand on the drawer's edge instead, the camera at
/// the thumb and the page on the far side, and the column is the way out and the zoom.
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
    /// The next page and the camera here, or on the drawer's edge.
    var showsPageButtons = true

    /// The buttons, their gaps, the slider at its shortest and the padding round them.
    static func heightWithZoom(pageButtons: Bool) -> CGFloat {
        let buttons: CGFloat = pageButtons ? 3 : 1
        return buttons * 44 + buttons * 14 + 60 + 24
    }

    var body: some View {
        VStack(alignment: side.horizontal, spacing: 14) {
            if let pageCount {
                StartOverButton(pageCount: pageCount, action: startOver)
            }
            if showsPageButtons {
                NextPageButton(
                    canAddPage: canAddPage, addPage: addPage, moveNextPage: moveNextPage)
                PageButton(
                    symbol: "camera", label: Text("Take another photo", bundle: .module),
                    action: retake)
            }
            if showsZoom {
                ZoomSlider(fraction: $zoom)
            }
        }
    }
}

/// The next page of a spread, or the second page moved round the first once there is one.
struct NextPageButton: View {
    let canAddPage: Bool
    let addPage: () -> Void
    var moveNextPage: (() -> Void)?

    var body: some View {
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
    }
}
