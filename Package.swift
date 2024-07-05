// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Salmon-Game",
    dependencies: [
        .package(url: "https://github.com/STREGAsGate/Raylib", branch: "master")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "Salmon-Game",
            dependencies: [
                .product(name: "Raylib", package: "Raylib")
            ],
            path: "Sources"),
    ]
)
