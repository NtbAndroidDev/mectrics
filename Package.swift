// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mectrics",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "Mectrics",
            targets: ["Mectrics"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Mectrics",
            path: "Sources",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
