// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ArchiveAtlas",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "ArchiveAtlas", targets: ["ArchiveAtlasApp"])
    ],
    targets: [
        .executableTarget(
            name: "ArchiveAtlasApp",
            path: "Sources/ArchiveAtlasApp"
        ),
        .testTarget(
            name: "ArchiveAtlasAppTests",
            dependencies: ["ArchiveAtlasApp"],
            path: "Tests/ArchiveAtlasAppTests"
        )
    ]
)
