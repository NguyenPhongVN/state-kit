import SwiftUI

struct ReferenceExamplesHomeView: View {
    private struct ExampleEntry: Identifiable {
        let id = UUID()
        let file: String
        let subtitle: String
        let screen: ExampleScreen
    }

    private enum ExampleScreen: Hashable {
        case computed
        case observable
        case asyncHook
        case atomMacros
        case hookMacros
        case family
        case nineMacros
        case showcase
        case featureFlags
        case cache
        case analytics
        case performance
        case swiftData
        case cloudKit
        case visionOS
        case ecommerce
        case architecture
    }

    private let macroExamples = [
        ExampleEntry(file: "ComputedMacroExample.swift", subtitle: "Derived values and memoized recomputation", screen: .computed),
        ExampleEntry(file: "ObservableStateMacroExample.swift", subtitle: "Observable model state transitions", screen: .observable),
        ExampleEntry(file: "AsyncHookMacroExample.swift", subtitle: "Async phase lifecycle and cancellation", screen: .asyncHook),
        ExampleEntry(file: "AtomMacrosExtendedExample.swift", subtitle: "Atom read/write and composition", screen: .atomMacros),
        ExampleEntry(file: "HookMacrosExtendedExample.swift", subtitle: "Effect, callback, and reducer-style hooks", screen: .hookMacros),
        ExampleEntry(file: "FamilyMacrosExample.swift", subtitle: "Parameterized state families", screen: .family),
        ExampleEntry(file: "Nine_New_Macros_Examples.swift", subtitle: "Mixed macro scenarios", screen: .nineMacros),
        ExampleEntry(file: "StateKitFullShowcase.swift", subtitle: "Full surface showcase", screen: .showcase),
    ]

    private let moduleExamples = [
        ExampleEntry(file: "FeatureFlagsExample.swift", subtitle: "Flag targeting and rollout controls", screen: .featureFlags),
        ExampleEntry(file: "CacheExample.swift", subtitle: "Cache behavior and invalidation", screen: .cache),
        ExampleEntry(file: "AnalyticsExample.swift", subtitle: "Event tracking and counters", screen: .analytics),
        ExampleEntry(file: "PerformanceOptimizationExample.swift", subtitle: "Filtering, throttling, and update isolation", screen: .performance),
    ]

    private let integrationExamples = [
        ExampleEntry(file: "SwiftDataIntegrationExample.swift", subtitle: "Persistence workflow", screen: .swiftData),
        ExampleEntry(file: "CloudKitIntegrationExample.swift", subtitle: "Sync status and conflict strategy", screen: .cloudKit),
        ExampleEntry(file: "VisionOSExample.swift", subtitle: "Spatial interaction state", screen: .visionOS),
        ExampleEntry(file: "ECommerceAppExample.swift", subtitle: "Catalog/cart/checkout flow", screen: .ecommerce),
        ExampleEntry(file: "ArchitectureShowcaseExample.swift", subtitle: "Cross-feature architecture composition", screen: .architecture),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Reference Folder") {
                    Text("Examples/CaseStudies/ReferenceExamplesApp/ReferenceExamples")
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section("1) Macros") {
                    ForEach(macroExamples) { item in
                        NavigationLink(value: item.screen) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.file)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("2) Modules") {
                    ForEach(moduleExamples) { item in
                        NavigationLink(value: item.screen) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.file)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("3) Integrations") {
                    ForEach(integrationExamples) { item in
                        NavigationLink(value: item.screen) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.file)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("ReferenceExamples")
            .navigationDestination(for: ExampleScreen.self) { screen in
                switch screen {
                case .computed: ComputedMacroExampleView()
                case .observable: ObservableStateMacroExampleView()
                case .asyncHook: AsyncHookMacroExampleView()
                case .atomMacros: AtomMacrosExtendedExampleView()
                case .hookMacros: HookMacrosExtendedExampleView()
                case .family: FamilyMacrosExampleView()
                case .nineMacros: NineNewMacrosExamplesView()
                case .showcase: StateKitFullShowcaseView()
                case .featureFlags: FeatureFlagsExampleView()
                case .cache: CacheExampleView()
                case .analytics: AnalyticsExampleView()
                case .performance: PerformanceOptimizationExampleView()
                case .swiftData: SwiftDataIntegrationExampleView()
                case .cloudKit: CloudKitIntegrationExampleView()
                case .visionOS: VisionOSExampleView()
                case .ecommerce: ECommerceAppExampleView()
                case .architecture: ArchitectureShowcaseExampleView()
                }
            }
        }
    }
}

#Preview {
    ReferenceExamplesHomeView()
}
