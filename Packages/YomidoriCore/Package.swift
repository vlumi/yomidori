// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YomidoriCore",
    defaultLocalization: "en",
    // iOS 26 is the app's floor. macOS is listed only so `swift test` runs headless
    // on the Mac, and a Mac app is planned (see ROADMAP).
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        // Pure logic — kana, readings, cards, scheduling. No UI, no camera. Headlessly testable.
        .library(name: "YomidoriCore", targets: ["YomidoriCore"]),
        // SwiftUI, the camera and Vision glue. Depends on YomidoriCore.
        .library(name: "YomidoriKit", targets: ["YomidoriKit"]),
    ],
    dependencies: [
        // MeCab compiled from source, with IPADic bundled: the one third-party runtime
        // dependency, quarantined in YomidoriMeCab so nothing else imports it and cutting
        // it is one line. Pinned to a commit; the package has no tags.
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
        // The bundled JMdict, read through the system's SQLite. The database itself is
        // built by Scripts/data/build-jmdict.py into the app target, not into this package,
        // so `swift test` needs no download; the tests read a fixture built the same way.
        .target(
            name: "YomidoriDictionary",
            dependencies: ["YomidoriCore"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // manga-ocr through Core ML, behind nothing but a CGImage in and a String out;
        // present at runtime only when the app bundles the models (see `make models`).
        .target(
            name: "YomidoriMangaOCR",
            dependencies: ["YomidoriCore"]
        ),
        // iCloud sync through CloudKit: the one target that talks to anything off the device,
        // and only to the reader's own iCloud.
        .target(
            name: "YomidoriSync",
            dependencies: ["YomidoriCore"]
        ),
        .target(
            name: "YomidoriKit",
            dependencies: [
                "YomidoriCore", "YomidoriMeCab", "YomidoriDictionary", "YomidoriMangaOCR",
                "YomidoriSync",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        // YomidoriKit is a dependency so `swift test` compiles it for macOS; no test imports it.
        .testTarget(
            name: "YomidoriCoreTests",
            dependencies: ["YomidoriCore", "YomidoriMeCab", "YomidoriDictionary", "YomidoriKit"],
            resources: [.copy("Dictionary/Fixtures")]
        ),
    ]
)
