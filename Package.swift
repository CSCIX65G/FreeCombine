// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "FreeCombine",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "FreeCombine",
            targets: [
                "FreeCombine"
            ]
        ),
        .library(
            name: "Time",
            targets: [
                "Time"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.0.2")),
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
        .target(
            name: "Time",
            dependencies: [
                "FreeCombine"
            ]
        ),
        .testTarget(
            name: "TimeTests",
            dependencies: [
                "Time"
            ]
        ),
    ]
)
