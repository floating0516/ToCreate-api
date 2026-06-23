// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiheAPI",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LiheAPI", targets: ["LiheAPI"])
    ],
    targets: [
        .executableTarget(name: "LiheAPI"),
        .testTarget(name: "LiheAPITests", dependencies: ["LiheAPI"])
    ]
)
