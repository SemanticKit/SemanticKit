// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "SemanticKit",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .visionOS(.v27)
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
        .package(url: "https://github.com/SemanticKit/IRIKit.git", branch: "main"),
        .package(url: "https://github.com/SemanticKit/RDFKit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "SemanticKit",
            dependencies: [
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "RDFCore", package: "RDFKit"),
                .product(name: "RDFFormats", package: "RDFKit"),
                .product(name: "RDFKit", package: "RDFKit")
            ],
        ),
        .testTarget(
            name: "SemanticKitTests",
            dependencies: [
                "SemanticKit"
            ],
            exclude: ["Fixtures"]
        ),
    ]
)
