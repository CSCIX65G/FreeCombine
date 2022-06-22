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
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "FreeCombine",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics")
            ]
        ),
        .testTarget(
            name: "FreeCombineTests",
            dependencies: ["FreeCombine"]
        ),
    ]
)
