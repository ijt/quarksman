// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "FeynmanDemo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "FeynmanDemo", path: "Sources/FeynmanDemo")
    ]
)
