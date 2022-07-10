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
        .library(
            name: "Time",
            targets: [
                "Time"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CSCIX65G/swift-atomics.git", branch: "CSCIX65G/playgrounds"),
    ],
    targets: [
        .target(
            name: "FreeCombine",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics")
            ],
            cSettings: [.define("DISABLE_SWIFT_RETAINRELEASE")]
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
