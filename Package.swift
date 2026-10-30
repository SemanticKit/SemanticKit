// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "SemanticKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "SemanticKit",
            targets: [
                "SemanticKit"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SemanticKit/IRIKit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "SemanticKit",
            dependencies: [
                .product(name: "IRIKit", package: "IRIKit")
            ],
        ),
        .testTarget(
            name: "SemanticKitTests",
            dependencies: [
                "SemanticKit"
            ],
        ),
    ]
)
