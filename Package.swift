// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SemanticKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SemanticKit",
            targets: [
                "SemanticKit"
            ]
        ),
        .executable(
            name: "SemanticKitGraphViewer",
            targets: [
                "SemanticKitGraphViewer"
            ]
        )
    ],
    targets: [
        .target(
            name: "SemanticKit",
            dependencies: [
            ]
        ),
        .executableTarget(
            name: "SemanticKitGraphViewer",
            dependencies: [
                "SemanticKit"
            ],
            swiftSettings: [
            ]
        ),
        .testTarget(
            name: "SemanticKitTests",
            dependencies: ["SemanticKit"]
        ),
    ]
)
