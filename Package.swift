// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ScreenAlign",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ScreenAlign", targets: ["ScreenAlign"]),
    ],
    targets: [
        .target(name: "ScreenAlignCore"),
        .executableTarget(name: "ScreenAlign", dependencies: ["ScreenAlignCore"]),
        .testTarget(name: "ScreenAlignCoreTests", dependencies: ["ScreenAlignCore"]),
    ]
)
