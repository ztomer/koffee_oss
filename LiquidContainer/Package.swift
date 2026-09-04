// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiquidContainer",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "LiquidContainer",
            targets: ["LiquidContainer"]
        )
    ],
    targets: [
        .target(
            name: "LiquidContainer",
            dependencies: [],
            resources: [
                .copy("default_config.json"),
                .copy("liquid_config.json")
            ]
        ),
        .testTarget(
            name: "LiquidContainerTests",
            dependencies: ["LiquidContainer"]
        )
    ]
)
