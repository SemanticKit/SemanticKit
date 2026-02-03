// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SemanticKit",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Iri",
            targets: [
                "Iri"
            ]
        ),
        .library(
            name: "Shared",
            targets: [
                "Shared"
            ]
        ),
        .library(
            name: "SemanticKit",
            targets: [
                "SemanticKit"
            ]
        ),
        .library(
            name: "Skos",
            targets: [
                "Skos"
            ]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Iri"
        ),
        .target(
            name: "Shared"
        ),
        .target(
            name: "SemanticKit",
            dependencies: [
                "Iri"
            ]
        ),
        .target(
            name: "Skos",
            dependencies: [
                "Iri",
                "SemanticKit"
            ]
        ),
        .testTarget(
            name: "IriTests",
            dependencies: ["Iri"]
        ),
        .testTarget(
            name: "SemanticKitTests",
            dependencies: ["SemanticKit"]
        ),
    ]
)
