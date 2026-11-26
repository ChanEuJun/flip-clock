// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FlipFocus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "FlipFocus", path: "Sources/FlipFocus")
    ]
)
