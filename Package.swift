// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
import CompilerPluginSupport

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
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/SemanticKit/IRIKit.git", branch: "wp/03a-iri-normalization")
    ],
    targets: [
        .target(
            name: "SemanticKit",
            dependencies: [
                "SemanticKitMacros",
                .product(name: "IRIKit", package: "IRIKit")
            ],
        ),
        .macro(
            name: "SemanticKitMacros",
            dependencies: [
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "SemanticKitTests",
            dependencies: [
                "SemanticKit",
                "SemanticKitMacros",
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax")
            ],
        ),
    ]
)
