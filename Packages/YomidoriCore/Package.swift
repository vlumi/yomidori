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
    dependencies: [
        // MeCab compiled from source, with IPADic bundled: the one third-party runtime
        // dependency, quarantined in YomidoriMeCab while the tokenizer choice is compared
        // in the field. Pinned to a commit; the package has no tags.
        .package(
            url: "https://github.com/shinjukunian/Mecab-Swift",
            revision: "1f096492e37fc05fc2e7304091f54889974c5368"),
    ],
    targets: [
        .target(name: "YomidoriCore"),
        // MeCab + IPADic behind Core's Tokenizer protocol. Its own target so that keeping
        // or cutting it is one line here, and nothing else imports the C++ library.
        .target(
            name: "YomidoriMeCab",
            dependencies: [
                "YomidoriCore",
                .product(name: "Mecab-Swift", package: "Mecab-Swift"),
                .product(name: "IPADic", package: "Mecab-Swift"),
            ]
        ),
        .target(
            name: "YomidoriKit",
            dependencies: ["YomidoriCore", "YomidoriMeCab"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "YomidoriCoreTests",
            dependencies: ["YomidoriCore", "YomidoriMeCab", "YomidoriKit"]
        ),
    ]
)
