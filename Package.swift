// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoggerKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LoggerKit",
            targets: ["LoggerKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", .upToNextMajor(from: "2.1.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LoggerKit",
            dependencies: [
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver")
            ],
            path: "Sources/LoggerKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LoggerKitTests",
            dependencies: ["LoggerKit"]
        ),
    ]
)
