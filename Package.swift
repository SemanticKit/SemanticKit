// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

// App in a SwiftPM Package https://clive819.github.io/posts/developing-an-ios-app-in-swift-package/
import AppleProductTypes
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
        ),
        .library(name: "SemanticKitGraphViewer", targets: ["SemanticKitGraphViewer"]),
    ],
    targets: [
        .target(
            name: "SemanticKit",
            dependencies: []
        ),
        .target(
            name: "SemanticKitGraphViewer",
            dependencies: [
                "SemanticKit"
            ],
            swiftSettings: []
        ),
        .testTarget(
            name: "SemanticKitTests",
            dependencies: ["SemanticKit"]
        ),
    ]
)
