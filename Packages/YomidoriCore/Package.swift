// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YomidoriCore",
    defaultLocalization: "en",
    // iOS 16 is the app's floor (an iPhone 8 still reads). macOS is listed only so
    // `swift test` runs headless on the Mac — there is no Mac app, and never will be.
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        // Pure logic — kana, readings, cards, scheduling. No UI, no camera. Headlessly testable.
        .library(name: "YomidoriCore", targets: ["YomidoriCore"]),
        // SwiftUI, the camera and Vision glue. Depends on YomidoriCore.
        .library(name: "YomidoriKit", targets: ["YomidoriKit"]),
    ],
    targets: [
        .target(name: "YomidoriCore"),
        .target(
            name: "YomidoriKit",
            dependencies: ["YomidoriCore"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "YomidoriCoreTests",
            dependencies: ["YomidoriCore", "YomidoriKit"]
        ),
    ]
)
