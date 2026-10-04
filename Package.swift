// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Quarksman",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .executableTarget(name: "Quarksman", path: "Sources/Quarksman", resources: [.copy("Resources/AppIcon.png")]),
        .testTarget(name: "QuarksmanTests", dependencies: ["Quarksman"], path: "Tests/QuarksmanTests"),
    ]
)
