// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RealtimeDecisionSystem",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CoreEngine",
            targets: ["CoreEngine"]
        )
    ],
    targets: [
        .target(
            name: "CoreEngine"
        ),
        .testTarget(
            name: "CoreEngineTests",
            dependencies: ["CoreEngine"]
        )
    ]
)
