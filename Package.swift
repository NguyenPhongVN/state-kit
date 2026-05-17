// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// Package layout:
// - Core runtime (`StateKitCore`, `StateKit`)
// - Optional feature modules (`StateKitUI`, `StateKitAtoms`, `Riverpods`, etc.)
// - Macro plugin + macro facade (`StateKitMacrosPlugin`, `StateKitMacros`)
// - Test targets per module for focused validation
let package = Package(
    name: "state-kit",
    // Minimum deployment targets chosen to align with modern Swift Concurrency
    // and Observation APIs used throughout the library.
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        // Core + base modules
        .library(name: "StateKitCore", targets: ["StateKitCore"]),
        .library(name: "StateKit", targets: ["StateKit"]),
        .library(name: "StateKitCombine", targets: ["StateKitCombine"]),
        .library(name: "StateKitUI", targets: ["StateKitUI"]),
        .library(name: "StateKitSupport", targets: ["StateKitSupport"]),
        .library(name: "StateKitTesting", targets: ["StateKitTesting"]),

        // Feature modules
        .library(name: "StateKitDevTools", targets: ["StateKitDevTools"]),
        .library(name: "StateKitPersistence", targets: ["StateKitPersistence"]),
        .library(name: "StateKitCache", targets: ["StateKitCache"]),
        .library(name: "StateKitFeatureFlags", targets: ["StateKitFeatureFlags"]),
        .library(name: "StateKitAnalytics", targets: ["StateKitAnalytics"]),
        .library(name: "StateKitAtoms", targets: ["StateKitAtoms"]),
        .library(name: "Riverpods", targets: ["Riverpods"]),
        .library(name: "StateConcurrency", targets: ["StateConcurrency"]),

        // Macros
        .library(name: "StateKitMacros", targets: ["StateKitMacros"]),
    ],
    dependencies: [
        // Macro parsing/expansion
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "603.0.0"),

        // Concurrency + testing support
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.0"),
    ],
    targets: [
        // MARK: - Runtime targets
        // Low-level primitives and internal runtime utilities.
        PackageDescription.Target.target(name: "StateKitCore"),

        // Public root module that re-exports core state primitives.
        PackageDescription.Target.target(name: "StateKit", dependencies: ["StateKitCore"]),

        // MARK: - Macro targets
        // Compiler plugin target responsible for macro expansion.
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

        // Public facade target exposing macro declarations to package consumers.
        // Depends on atoms/riverpods because generated code references these APIs.
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

        // MARK: - Optional/feature targets
        // Combine helpers for integrating StateKit with existing Combine pipelines.
        PackageDescription.Target.target(
            name: "StateKitCombine",
            dependencies: ["StateKit", "StateKitAtoms"]
        ),

        // Concurrency utilities and adapters for strict concurrency workflows.
        PackageDescription.Target.target(
            name: "StateConcurrency",
            dependencies: [
                PackageDescription.Target.Dependency.byName(name: "StateKit"),
                PackageDescription.Target.Dependency.product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                PackageDescription.Target.Dependency.product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ],
            exclude: ["README.md"]
        ),

        // SwiftUI-oriented bindings/components on top of StateKit runtime.
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

        // Testing helpers for deterministic state assertions and fixtures.
        PackageDescription.Target.target(name: "StateKitTesting", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "Riverpods")
        ]),

        // Shared extension points/utilities consumed by multiple feature modules.
        PackageDescription.Target.target(name: "StateKitSupport", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "StateKitCore"),
            PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")
        ]),

        // Diagnostics, inspection, and developer-facing tooling.
        PackageDescription.Target.target(name: "StateKitDevTools", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "Riverpods")
        ]),

        // Persistence adapters for saving/restoring state.
        PackageDescription.Target.target(name: "StateKitPersistence", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "Riverpods"),
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")
        ]),

        // Cache primitives for provider-driven memoization and lookup.
        PackageDescription.Target.target(
            name: "StateKitCache",
            dependencies: [PackageDescription.Target.Dependency.byName(name: "Riverpods")]
        ),

        // Runtime feature flag model and evaluation APIs.
        PackageDescription.Target.target(name: "StateKitFeatureFlags", dependencies: []),

        // Analytics integration primitives centered on state events.
        PackageDescription.Target.target(
            name: "StateKitAnalytics",
            dependencies: [PackageDescription.Target.Dependency.byName(name: "Riverpods")]
        ),

        // Atom-based global state layer inspired by Recoil/Jotai.
        PackageDescription.Target.target(
            name: "StateKitAtoms",
            dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKit")],
            exclude: ["README.md"]
        ),

        // Riverpod-style provider/runtime implementation for Swift.
        PackageDescription.Target.target(name: "Riverpods", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKit"),
            PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")
        ]),

        // MARK: - Test targets
        // Integration-level tests for top-level StateKit APIs.
        PackageDescription.Target.testTarget(
            name: "StateKitTests",
            dependencies: [
                PackageDescription.Target.Dependency.byName(name: "StateKit"),
                PackageDescription.Target.Dependency.byName(name: "StateKitCombine"),
                PackageDescription.Target.Dependency.byName(name: "StateKitTesting")
            ]
        ),

        // Unit tests for StateKitCore internals.
        PackageDescription.Target.testTarget(
            name: "StateKitCoreTests",
            dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitCore")]
        ),

        // UI-specific behavior and rendering contract tests.
        PackageDescription.Target.testTarget(name: "StateKitUITests", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKitUI"),
            PackageDescription.Target.Dependency.byName(name: "StateKitTesting")
        ]),

        // Support module correctness and helper behavior tests.
        PackageDescription.Target.testTarget(name: "StateKitSupportTests", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "StateKitSupport"),
            PackageDescription.Target.Dependency.byName(name: "StateKitTesting")
        ]),

        // Concurrency correctness and race-condition prevention tests.
        PackageDescription.Target.testTarget(
            name: "StateConcurrencyTests",
            dependencies: [PackageDescription.Target.Dependency.byName(name: "StateConcurrency")]
        ),

        // Atom store semantics and propagation tests.
        PackageDescription.Target.testTarget(
            name: "StateKitAtomsTests",
            dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")]
        ),

        // Macro expansion and diagnostics tests.
        PackageDescription.Target.testTarget(
            name: "StateKitMacrosTests",
            dependencies: [
                PackageDescription.Target.Dependency.byName(name: "StateKitMacros"),
                PackageDescription.Target.Dependency.byName(name: "StateKitUI"),
                PackageDescription.Target.Dependency.byName(name: "StateKitMacrosPlugin"),
                PackageDescription.Target.Dependency.product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),

        // Riverpod-style provider graph behavior tests.
        PackageDescription.Target.testTarget(name: "RiverpodsTests", dependencies: [
            PackageDescription.Target.Dependency.byName(name: "Riverpods"),
            PackageDescription.Target.Dependency.byName(name: "StateKitAtoms")
        ]),

        // Feature module validation tests.
        PackageDescription.Target.testTarget(
            name: "StateKitCacheTests",
            dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitCache")]
        ),
        PackageDescription.Target.testTarget(
            name: "StateKitFeatureFlagsTests",
            dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitFeatureFlags")]
        ),
        PackageDescription.Target.testTarget(
            name: "StateKitAnalyticsTests",
            dependencies: [PackageDescription.Target.Dependency.byName(name: "StateKitAnalytics")]
        ),
    ]
)
