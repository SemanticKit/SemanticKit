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
        .package(url: "https://github.com/SemanticKit/IRIKit.git", branch: "main")
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
                "SemanticKitMacroImplementations",
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        // The macro expansions live in a plain library so the test target can
        // expand them without depending on the macro target itself.
        .target(
            name: "SemanticKitMacroImplementations",
            dependencies: [
                .product(name: "IRIKit", package: "IRIKit"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "SemanticKitTests",
            dependencies: [
                "SemanticKit",
                "SemanticKitMacroImplementations",
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax")
            ],
        ),
    ]
)
