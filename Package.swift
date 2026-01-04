// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ContinuityCore",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "ContinuityCore",
            targets: ["ContinuityCore"]
        ),
    ],
    targets: [
        .target(
            name: "ContinuityCore",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
