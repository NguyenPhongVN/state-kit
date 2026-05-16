// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "state-kit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "StateKitCore", targets: ["StateKitCore"]),
        .library(name: "StateKit", targets: ["StateKit"]),
        .library(name: "StateKitCombine", targets: ["StateKitCombine"]),
        .library(name: "StateKitUI", targets: ["StateKitUI"]),
        .library(name: "StateKitSupport", targets: ["StateKitSupport"]),
        .library(name: "StateKitTesting", targets: ["StateKitTesting"]),
        .library(name: "StateKitDevTools", targets: ["StateKitDevTools"]),
        .library(name: "StateKitPersistence", targets: ["StateKitPersistence"]),
        .library(name: "StateKitCache", targets: ["StateKitCache"]),
        .library(name: "StateKitFeatureFlags", targets: ["StateKitFeatureFlags"]),
        .library(name: "StateKitAnalytics", targets: ["StateKitAnalytics"]),
        .library(name: "StateKitAtoms", targets: ["StateKitAtoms"]),
        .library(name: "Riverpods", targets: ["Riverpods"]),
        .library(name: "StateConcurrency", targets: ["StateConcurrency"]),
        .library(name: "StateKitMacros", targets: ["StateKitMacros"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "603.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.0"),
    ],
    targets: [
        PackageDescription.Target.target(name: "StateKitCore"),
        PackageDescription.Target.target(name: "StateKit", dependencies: ["StateKitCore"]),
        Target.macro(
            name: "StateKitMacrosPlugin",
            dependencies: [
                Target.Dependency.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                Target.Dependency.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"], .when(configuration: .debug)),
                .unsafeFlags(["-suppress-warnings"], .when(configuration: .release))
            ]
        ),
        Target.target(
            name: "StateKitMacros",
            dependencies: [
                Target.Dependency.byName(name: "StateKitMacrosPlugin"),
                Target.Dependency.byName(name: "StateKitAtoms"),
                Target.Dependency.byName(name: "Riverpods"),
                Target.Dependency.product(name: "SwiftSyntax", package: "swift-syntax"),
                Target.Dependency.product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                Target.Dependency.product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        PackageDescription.Target.target(
            name: "StateKitCombine",
            dependencies: ["StateKit", "StateKitAtoms"]
        ),
        PackageDescription.Target.target(
            name: "StateConcurrency",
            dependencies: [
                PackageDescription.Target.Dependency.byName(name: "StateKit"),
                PackageDescription.Target.Dependency.product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                PackageDescription.Target.Dependency.product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ],
            exclude: ["README.md"]
        ),
        PackageDescription.Target.target(
            name: "StateKitUI",
            dependencies: [
                PackageDescription.Target.Dependency.byName(name: "StateKit"),
                PackageDescription.Target.Dependency.byName(name: "StateKitCore"),
                PackageDescription.Target.Dependency.byName(name: "StateKitAtoms"),
                PackageDescription.Target.Dependency.byName(name: "StateKitSupport")
            ],
            exclude: ["README.md"]
        ),
        PackageDescription.Target.target(name: "StateKitTesting", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "Riverpods")
        ]),
        PackageDescription.Target.target(name: "StateKitSupport", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "StateKitCore"),
            PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")
        ]),
        PackageDescription.Target.target(name: "StateKitDevTools", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "Riverpods")
        ]),
        PackageDescription.Target.target(name: "StateKitPersistence", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "Riverpods"),
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")
        ]),
        PackageDescription.Target.target(name: "StateKitCache", dependencies: [PackageDescription.Target.Dependency.byName(name: "Riverpods")]),
        PackageDescription.Target.target(name: "StateKitFeatureFlags", dependencies: []),
        PackageDescription.Target.target(name: "StateKitAnalytics", dependencies: [PackageDescription.Target.Dependency.byName(name: "Riverpods")]),
        PackageDescription.Target.target(name: "StateKitAtoms", dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKit")], exclude: ["README.md"]),
        PackageDescription.Target.target(name: "Riverpods", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")
        ]),
        PackageDescription.Target.testTarget(
            name: "StateKitTests",
            dependencies: [
                PackageDescription.Target.Dependency.byName(name: "StateKit"),
                PackageDescription.Target.Dependency.byName(name: "StateKitCombine"),
                PackageDescription.Target.Dependency.byName(name: "StateKitTesting")
            ]
        ),
        PackageDescription.Target.testTarget(name: "StateKitCoreTests", dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitCore")]),
        PackageDescription.Target.testTarget(name: "StateKitUITests", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKitUI"),
            PackageDescription.Target.Dependency.byName(name: "StateKitTesting")
        ]),
        PackageDescription.Target.testTarget(name: "StateKitSupportTests", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKitSupport"),
            PackageDescription.Target.Dependency.byName(name: "StateKitTesting")
        ]),
        PackageDescription.Target.testTarget(name: "StateConcurrencyTests", dependencies: [PackageDescription.Target.Dependency.byName(name: "StateConcurrency")]),
        PackageDescription.Target.testTarget(name: "StateKitAtomsTests", dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")]),
        PackageDescription.Target.testTarget(
            name: "StateKitMacrosTests",
            dependencies: [
                PackageDescription.Target.Dependency.byName(name: "StateKitMacrosPlugin"),
                PackageDescription.Target.Dependency.product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        PackageDescription.Target.testTarget(name: "RiverpodsTests", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "Riverpods"),
            PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")
        ]),
        PackageDescription.Target.testTarget(name: "StateKitCacheTests", dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitCache")]),
        PackageDescription.Target.testTarget(name: "StateKitFeatureFlagsTests", dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitFeatureFlags")]),
        PackageDescription.Target.testTarget(name: "StateKitAnalyticsTests", dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitAnalytics")]),
    ]
)
