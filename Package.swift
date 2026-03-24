// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "state-kit",
    platforms: [
        .iOS(.v17),        // iOS 17.0+ for latest SwiftUI features
        .macOS(.v14),      // macOS 14.0+ for latest system APIs
        .tvOS(.v17),       // tvOS 17.0+ for latest tvOS features
        .watchOS(.v10),    // watchOS 10.0+ for latest watchOS capabilities
        .visionOS(.v1)     // visionOS 1.0+ for visionOS support
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "StateKitCore",
            targets: ["StateKitCore"]
        ),
        .library(
            name: "StateKit",
            targets: ["StateKit"]
        ),
        .library(
            name: "StateKitCombine",
            targets: ["StateKitCombine"]
        ),
        .library(
            name: "StateKitUI",
            targets: ["StateKitUI"]
        ),
        .library(
            name: "StateKitSupport",
            targets: ["StateKitSupport"]
        ),
        .library(
            name: "StateKitTesting",
            targets: ["StateKitTesting"]
        ),
        .library(
            name: "StateKitDevTools",
            targets: ["StateKitDevTools"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "StateKitCore"
        ),
        .target(
            name: "StateKit",
            dependencies: [
                "StateKitCore",
            ]
        ),
        .target(
            name: "StateKitMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "StateKitCombine",
            dependencies: [
                "StateKit"
            ]
        ),
        .target(
            name: "StateConcurrency",
            dependencies: [
                "StateKit",
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .target(
            name: "StateKitUI",
            dependencies: [
                "StateKit",
                "StateKitCore"
            ]
        ),
        .target(
            name: "StateKitTesting"
            ,
            dependencies: [
                "StateKit"
            ]
        ),
        .target(
            name: "StateKitSupport",
            dependencies: [
                "StateKit"
            ]
        ),
        .target(
            name: "StateKitDevTools",
            dependencies: [
                "StateKit"
            ]
        ),
        .testTarget(
            name: "StateKitTests",
            dependencies: [
                "StateKit",
                "StateKitTesting"
            ]
        ),
    ]
)
