// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Examples",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .executable(name: "ReferenceExamplesApp", targets: ["ReferenceExamplesApp"])
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "ReferenceExamplesApp",
            dependencies: [
                .product(name: "StateKit", package: "state-kit"),
                .product(name: "StateKitAtoms", package: "state-kit"),
                .product(name: "StateKitUI", package: "state-kit"),
                .product(name: "StateKitMacros", package: "state-kit"),
                .product(name: "Riverpods", package: "state-kit"),
                .product(name: "StateKitAnalytics", package: "state-kit"),
                .product(name: "StateKitCache", package: "state-kit"),
                .product(name: "StateKitFeatureFlags", package: "state-kit"),
            ],
            path: "CaseStudies/ReferenceExamplesApp"
        )
    ]
)
