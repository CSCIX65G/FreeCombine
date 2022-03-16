// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "FreeCombine",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
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
