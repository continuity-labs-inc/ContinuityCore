// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ContinuityCore",
    platforms: [
        .iOS("26.0"),
        .watchOS("26.0"),
        .macOS("26.0")
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
