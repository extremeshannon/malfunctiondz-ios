// swift-tools-version: 5.10
// Shared platform layer for Alaska Skydive Center staff and member iOS apps.
import PackageDescription

let package = Package(
    name: "MalfunctionDZCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MalfunctionDZCore", targets: ["MalfunctionDZCore"]),
    ],
    targets: [
        .target(
            name: "MalfunctionDZCore",
            dependencies: []
        ),
        .testTarget(
            name: "MalfunctionDZCoreTests",
            dependencies: ["MalfunctionDZCore"]
        ),
    ]
)
