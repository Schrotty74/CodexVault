// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexVault",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "CodexVault", targets: ["CodexVaultApp"])
    ],
    targets: [
        .executableTarget(
            name: "CodexVaultApp",
            path: "Sources/CodexVaultApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CodexVaultAppTests",
            dependencies: ["CodexVaultApp"],
            path: "Tests/CodexVaultAppTests"
        )
    ]
)
