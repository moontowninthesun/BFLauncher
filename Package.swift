// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BFLauncher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BFLauncher", targets: ["BFLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "BFLauncher",
            path: "Sources/BFLauncher",
            resources: [
                .copy("Resources/BFGEmblem.png")
            ]
        )
    ]
)
