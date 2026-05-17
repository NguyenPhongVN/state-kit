# DevTools Integration Guide

**Version**: 2.2.0  
**Date**: May 17, 2026  
**Purpose**: Integrating DevTools with StateKit architecture patterns

---

## Overview

This guide shows how to integrate StateKit DevTools with the architectural patterns from Phase 2 (Architecture Guide, Modularity Guide, Feature Templates).

---

## Architecture Patterns Integration

### Pattern 1: Local State (Hooks) + DevTools

DevTools can monitor hook-based state changes:

```swift
import StateKit
import StateKitDevTools

// Track hook usage with DevTools
@MainActor
class ComponentState {
    @useState var count = 0
    @useEffect {
        // Log state changes
        print("Count changed: \(count)")
    }

    func increment() {
        count += 1
    }
}

// Best Practice: Use with Named Providers
let hookStateProvider = Provider(name: "componentState") { ref in
    // Wrap hook state in provider for tracking
    let state = ref.watch(stateProvider)
    return state
}
```

**DevTools Observation**:
```swift
let devTools = DevToolsObserver()
let container = ProviderContainer(observers: [devTools])

// Hook state changes are captured if wrapped in providers
for metric in devTools.metrics.slowestProviders {
    print("Slow hook state: \(metric.providerName)")
}
```

### Pattern 2: Global State (Atoms) + DevTools

Atoms are automatically tracked by DevTools:

```swift
import StateKitAtoms
import StateKitDevTools

// Atoms are monitored automatically
let countAtom = SKStateAtom(0, name: "globalCount")

// Use in component
@Watch(countAtom) var count

// DevTools tracks all atom updates
let devTools = DevToolsObserver()
let container = ProviderContainer(observers: [devTools])

// Later: check atom performance
let atomMetrics = devTools.metrics.updateFrequency(for: "globalCount")
print("Count updates: \(atomMetrics) Hz")
```

### Pattern 3: Business Logic (Riverpods) + DevTools

DevTools fully integrates with notifier-based state:

```swift
import Riverpods
import StateKitDevTools

// Define notifier with named provider
@Notifier
class CounterNotifier: Notifier<Int> {
    override func build() -> Int { 0 }
    func increment() { state += 1 }
}

let counterProvider = NotifierProvider(
    name: "counter",
    builder: { CounterNotifier() }
)

// Setup DevTools
let devTools = DevToolsObserver()
let container = ProviderContainer(observers: [devTools])

// All notifier updates are tracked
let notifier = container.read(counterProvider.notifier)
notifier.increment()  // ← Recorded in history

// Inspect history
for entry in devTools.history.entries {
    print("\(entry.action ?? "init"): \(entry.computeTime)ms")
}
```

---

## Feature Module Integration

### Complete Feature with DevTools

Here's a complete feature module using DevTools:

```swift
// MARK: - Models

struct ShoppingState: Sendable {
    var items: [Product] = []
    var total: Double = 0
    var isLoading = false
    var error: String?
}

// MARK: - Notifier

@Notifier
class ShoppingNotifier: Notifier<ShoppingState> {
    override func build() -> ShoppingState {
        ShoppingState()
    }

    func addItem(_ product: Product) {
        state.items.append(product)
        state.total += product.price
    }

    func loadItems() async {
        state.isLoading = true
        state.error = nil

        do {
            let products = try await fetchProducts()
            state.items = products
            state.total = products.map { $0.price }.reduce(0, +)
            state.isLoading = false
        } catch {
            state.error = error.localizedDescription
            state.isLoading = false
        }
    }
}

// MARK: - Provider with DevTools Integration

let shoppingProvider = NotifierProvider(
    name: "shopping",
    cacheTime: 300.0
) { ShoppingNotifier() }

let itemCountProvider = Provider(name: "itemCount") { ref in
    let state = ref.watch(shoppingProvider)
    return state.items.count
}

let cartTotalProvider = Provider(name: "cartTotal") { ref in
    let state = ref.watch(shoppingProvider)
    return state.total
}

// MARK: - Setup with DevTools

func setupShoppingFeature() -> ProviderContainer {
    #if DEBUG
    let devTools = DevToolsObserver()
    devTools.debugLoggingEnabled = true
    return ProviderContainer(observers: [devTools])
    #else
    return ProviderContainer()
    #endif
}

// MARK: - Debugging View (Debug Only)

#if DEBUG
struct ShoppingDebugView: View {
    @Environment(\.providerContainer) var container
    @State var showMetrics = false

    var body: some View {
        VStack {
            Button("Show Metrics") { showMetrics.toggle() }

            if showMetrics {
                MetricsView()
            }
        }
    }
}

struct MetricsView: View {
    @Environment(\.providerContainer) var container

    var body: some View {
        // Access DevTools from container
        // Note: May need custom extension to expose devTools
        Text("Metrics View")
    }
}
#endif
```

---

## Modularity with DevTools

### Cross-Module Performance Monitoring

Track performance across module boundaries:

```swift
// Setup: AppComposition/DependencyContainer.swift

struct DependencyContainer {
    let container: ProviderContainer

    #if DEBUG
    let devTools: DevToolsObserver?
    #else
    let devTools: DevToolsObserver? = nil
    #endif

    static func production() -> DependencyContainer {
        #if DEBUG
        let devTools = DevToolsObserver()
        let container = ProviderContainer(observers: [devTools])
        #else
        let container = ProviderContainer()
        let devTools: DevToolsObserver? = nil
        #endif

        return DependencyContainer(
            container: container,
            devTools: devTools
        )
    }

    /// Gets performance metrics across all features
    func getModuleMetrics() -> [String: PerformanceData] {
        guard let devTools = devTools else { return [:] }

        var metrics: [String: PerformanceData] = [:]
        for data in devTools.metrics.allMetrics {
            metrics[data.providerName] = data
        }
        return metrics
    }

    /// Identifies slow cross-module dependencies
    func findSlowCrossFunctionCalls() -> [String] {
        guard let devTools = devTools else { return [] }

        return devTools.metrics.slowestProviders
            .filter { $0.isSlowProvider }
            .map { $0.providerName }
    }
}
```

### Debugging Module Interactions

```swift
// AppComposition/DebugTools.swift

#if DEBUG
struct ModuleDebugger {
    let devTools: DevToolsObserver

    /// Exports performance metrics for each feature module
    func exportModuleMetrics() -> String {
        var report = "Module Performance Report\n"
        report += "==========================\n\n"

        let metrics = devTools.metrics.allMetrics
        let grouped = Dictionary(grouping: metrics) { metric in
            // Group by module (extract prefix from provider name)
            metric.providerName.split(separator: ".").first.map(String.init) ?? "unknown"
        }

        for (module, metrics) in grouped.sorted(by: { $0.key < $1.key }) {
            report += "## \(module)\n"
            let slowest = metrics.sorted {
                $0.averageComputeTime > $1.averageComputeTime
            }.prefix(3)

            for metric in slowest {
                report += "  - \(metric.providerName): \(metric.averageComputeTime)ms\n"
            }
            report += "\n"
        }

        return report
    }

    /// Identifies problematic inter-module dependencies
    func findProblematicDependencies() -> [(from: String, to: String, time: Double)] {
        var problems: [(from: String, to: String, time: Double)] = []

        for metric in devTools.metrics.slowestProviders.filter({ $0.isSlowProvider }) {
            problems.append((from: metric.providerName, to: "", time: metric.averageComputeTime))
        }

        return problems
    }
}
#endif
```

---

## Testing with DevTools

### Performance Testing

```swift
import XCTest
import StateKitDevTools

final class PerformanceTests: XCTestCase {
    func testCounterPerformance() {
        let devTools = DevToolsObserver()
        let container = ProviderContainer(observers: [devTools])

        let notifier = container.read(counterProvider.notifier)

        // Perform operation
        for _ in 0..<100 {
            notifier.increment()
        }

        // Check metrics
        let computeTime = devTools.metrics.computeTime(for: "counter")
        XCTAssertLessThan(computeTime, 1.0)  // Less than 1ms per update

        let frequency = devTools.metrics.updateFrequency(for: "counter")
        print("Update frequency: \(frequency) Hz")
    }

    func testHistoryRecording() {
        let devTools = DevToolsObserver()
        let container = ProviderContainer(observers: [devTools])

        let notifier = container.read(counterProvider.notifier)
        notifier.increment()

        // Verify history recorded
        XCTAssertEqual(devTools.history.entries.count, 1)
        XCTAssertEqual(devTools.history.currentIndex, 0)
    }

    func testStateTimeTravel() {
        let devTools = DevToolsObserver()
        let container = ProviderContainer(observers: [devTools])

        let notifier = container.read(counterProvider.notifier)

        notifier.increment()  // State: 1
        notifier.increment()  // State: 2
        notifier.increment()  // State: 3

        // Travel back
        XCTAssertTrue(devTools.history.canGoBack)
        let previousState = devTools.goBack()
        XCTAssertEqual(devTools.history.currentIndex, 1)

        // Travel forward
        XCTAssertTrue(devTools.history.canGoForward)
        let nextState = devTools.goForward()
        XCTAssertEqual(devTools.history.currentIndex, 2)
    }
}
```

---

## Production Considerations

### Memory Management

DevTools uses memory for history and metrics. Manage carefully:

```swift
// Configure for production debugging sessions
let devTools = DevToolsObserver()

// Limit to recent history only
devTools.maxHistoryEntries = 20

// Limit metrics records
devTools.maxMetricsRecords = 100

// Disable snapshots if memory is critical
devTools.storeSnapshots = false

let container = ProviderContainer(observers: [devTools])
```

### Conditional Compilation

Always use conditional compilation:

```swift
// AppDelegate or entry point

#if DEBUG
let debugObservers: [ProviderObserver] = [
    DevToolsObserver(),
    ConsoleLoggerObserver()
]
#else
let debugObservers: [ProviderObserver] = []
#endif

let container = ProviderContainer(observers: debugObservers)
```

### Remote Debugging

Export debug information for analysis:

```swift
// Send debug data to server for analysis
func sendDebugData(devTools: DevToolsObserver) async throws {
    let jsonData = devTools.exportAsJSON()

    var request = URLRequest(url: debugURL)
    request.httpMethod = "POST"
    request.httpBody = jsonData.data(using: .utf8)

    let (_, response) = try await URLSession.shared.data(for: request)
    // Process response
}
```

---

## Best Practices Checklist

- [ ] Name all providers for accurate tracking
- [ ] Use DevTools in DEBUG builds only
- [ ] Configure memory limits appropriately
- [ ] Periodically export debug data
- [ ] Monitor slowest providers weekly
- [ ] Track performance metrics trends
- [ ] Document expected performance baselines
- [ ] Use history debugging during development
- [ ] Clean up debug code before release
- [ ] Test DevTools integration

---

## Related Documents

- [DEVTOOLS_GUIDE.md](DEVTOOLS_GUIDE.md) - DevTools API guide
- [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md) - Architecture patterns
- [MODULARITY_GUIDE.md](MODULARITY_GUIDE.md) - Module organization
- [FEATURE_MODULE_TEMPLATES.md](FEATURE_MODULE_TEMPLATES.md) - Feature templates

---

## FAQ

**Q: Will DevTools slow down my app?**  
A: Only when enabled. In release builds with no observers, there's zero overhead. In debug, impact is minimal (<1ms per update).

**Q: How much memory does history use?**  
A: Depends on state size and history limit. Default 100 entries × small state = ~1-5MB.

**Q: Can I use DevTools in production?**  
A: Yes, but only in special debug builds. Always disable for regular production releases.

**Q: How do I analyze exported data?**  
A: The exported JSON contains all history and metrics. Parse with standard tools or upload to analysis service.

**Q: What about privacy?**  
A: State snapshots may contain sensitive data. Consider disabling `storeSnapshots` or clearing history before sharing.

---

**Version**: 2.2.0  
**Status**: Production Ready  
**Last Updated**: May 17, 2026
