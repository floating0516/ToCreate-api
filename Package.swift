// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiheAPI",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LiheAPI", targets: ["LiheAPI"])
    ],
    targets: [
        .executableTarget(
            name: "LiheAPI",
            path: ".",
            exclude: [
                "README.md",
                "Resources",
                "Tests",
                "docs",
                "scripts"
            ],
            sources: [
                "Sources/LiheAPI",
                "Shared"
            ]
        ),
        .testTarget(name: "LiheAPITests", dependencies: ["LiheAPI"])
    ]
)
