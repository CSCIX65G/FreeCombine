// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "FreeCombine",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "FreeCombine",
            targets: [
                "FreeCombine"
            ]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "FreeCombine",
            dependencies: []
        ),
        .testTarget(
            name: "FreeCombineTests",
            dependencies: ["FreeCombine"]
        ),
    ]
)
