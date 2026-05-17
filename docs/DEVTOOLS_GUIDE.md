# StateKit DevTools Guide

**Version**: 2.2.0-beta  
**Date**: May 17, 2026  
**Status**: Phase 3 - In Development

---

## Overview

StateKit DevTools provides professional-grade debugging capabilities for state management, including time-travel debugging, performance profiling, and real-time metrics collection.

**Key Features**:
- ✅ Time-Travel Debugging: Step forward/backward through state history
- ✅ Performance Profiling: Track compute time, update frequency, memory usage
- ✅ State Inspection: View and analyze historical state values
- ✅ Action Replay: Reproduce specific state sequences
- ✅ Performance Reports: Identify bottlenecks and optimization opportunities

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Time-Travel Debugging](#time-travel-debugging)
3. [Performance Profiling](#performance-profiling)
4. [State Inspection](#state-inspection)
5. [Action Replay](#action-replay)
6. [Reports and Export](#reports-and-export)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Installation

DevTools is included in StateKit v2.2+. No additional dependencies required.

### Basic Setup

```swift
import SwiftUI
import StateKitDevTools

// Create DevTools observer
let devTools = DevToolsObserver()

// Initialize container with DevTools
let container = ProviderContainer(observers: [devTools])

// Use in your app
@Environment(\.providerContainer) var container
```

### Development Only

Disable DevTools in production builds:

```swift
#if DEBUG
let devTools = DevToolsObserver()
let observers: [ProviderObserver] = [devTools]
#else
let observers: [ProviderObserver] = []
#endif

let container = ProviderContainer(observers: observers)
```

---

## Time-Travel Debugging

### Concept

Time-Travel Debugging records every state change, allowing you to:
- **Step backward**: Revert to any previous state
- **Step forward**: Move through state history
- **Jump to point**: Go directly to specific state
- **Inspect changes**: View what changed between states

### Recording History

History is **automatically recorded** when using DevTools observer:

```swift
// DevTools automatically records all provider updates
let devTools = DevToolsObserver()
let container = ProviderContainer(observers: [devTools])

// Every state change is captured
let notifier = container.read(myProvider.notifier)
notifier.updateState()  // ← Recorded automatically
```

### Navigating History

```swift
let devTools = DevToolsObserver()

// Check history state
print("Total entries: \(devTools.history.entries.count)")
print("Current position: \(devTools.history.currentIndex)")

// Navigate backward
if devTools.history.canGoBack {
    let previousState = devTools.goBack()
    // Apply previousState to restore app state
}

// Navigate forward
if devTools.history.canGoForward {
    let nextState = devTools.goForward()
}

// Jump to specific point
let targetState = devTools.jumpToHistoryIndex(5)
```

### Inspecting History Entries

```swift
// View all history entries
for (index, entry) in devTools.history.entries.enumerated() {
    print("[\(index)] \(entry.action ?? "init")")
    print("  Time: \(entry.timestamp)")
    print("  Compute: \(entry.computeTime)ms")
    print("  Before: \(entry.stateBefore)")
    print("  After: \(entry.stateAfter)")
}

// Current state
if let current = devTools.history.currentState {
    print("Current state: \(current)")
}
```

### Configuration

```swift
var devTools = DevToolsObserver()

// Limit history size (default: 100)
devTools.maxHistoryEntries = 50

// Whether to store full state snapshots
devTools.storeSnapshots = true  // More memory, better inspection

// Enable debug logging
devTools.debugLoggingEnabled = true
```

---

## Performance Profiling

### Metrics Tracked

For each provider, DevTools tracks:

| Metric | Unit | Purpose |
|--------|------|---------|
| **Update Frequency** | Hz | How often it updates |
| **Average Compute Time** | ms | Time to compute value |
| **Min/Max Compute Time** | ms | Performance range |
| **Total Call Count** | count | How many times computed |
| **Estimated Memory** | bytes | State size estimate |

### Accessing Metrics

```swift
let devTools = DevToolsObserver()

// Get all metrics
for metric in devTools.metrics.allMetrics {
    print("\(metric.providerName):")
    print("  Frequency: \(metric.updateFrequency) Hz")
    print("  Compute: \(metric.averageComputeTime) ms")
    print("  Calls: \(metric.totalCallCount)")
}

// Get top slow providers
for (idx, metric) in devTools.metrics.slowestProviders.enumerated() {
    print("\(idx + 1). \(metric.providerName): \(metric.averageComputeTime)ms")
}

// Get frequently updated providers
for (idx, metric) in devTools.metrics.mostUpdated.enumerated() {
    print("\(idx + 1). \(metric.providerName): \(metric.updateFrequency) Hz")
}

// Check specific provider
let freq = devTools.metrics.updateFrequency(for: "myProvider")
let time = devTools.metrics.computeTime(for: "myProvider")
let calls = devTools.metrics.callCount(for: "myProvider")
```

### Recording Custom Computations

Track performance of custom logic:

```swift
let devTools = DevToolsObserver()

// Record a computation
devTools.startComputation(providerName: "expensiveOperation")
let result = try await performExpensiveCalculation()
devTools.endComputation(
    providerName: "expensiveOperation",
    memoryBytes: MemoryLayout.size(ofValue: result)
)
```

### Performance Alerts

Identify concerning performance:

```swift
for metric in devTools.metrics.allMetrics {
    if metric.isSlowProvider {
        print("⚠️ Slow: \(metric.providerName) (\(metric.averageComputeTime)ms)")
    }

    if metric.isFrequentlyUpdated {
        print("⚠️ Frequent: \(metric.providerName) (\(metric.updateFrequency) Hz)")
    }

    print("Performance Score: \(metric.performanceScore)/100")
}
```

### Configuration

```swift
var devTools = DevToolsObserver()

// Limit metrics history (default: 1000)
devTools.maxMetricsRecords = 500

// Trade-off: snapshots = better inspection but more memory
devTools.storeSnapshots = true
```

---

## State Inspection

### Viewing Current State

```swift
// Current state at present position
if let currentState = devTools.history.currentState {
    print("Current: \(currentState)")
}

// State at specific point
let entry = devTools.history.entries[5]
print("State before: \(entry.stateBefore)")
print("State after: \(entry.stateAfter)")
```

### Comparing States

```swift
// Find what changed between two points
let before = devTools.history.entries[2].stateAfter
let after = devTools.history.entries[3].stateBefore

print("Difference:")
print("  Before: \(before)")
print("  After: \(after)")
```

### Searching History

```swift
// Find entries by action
let loginEntries = devTools.history.entries.filter { entry in
    entry.action?.lowercased().contains("login") ?? false
}

// Find slow operations
let slowOps = devTools.history.entries.filter { entry in
    entry.computeTime > 50.0  // > 50ms
}

// Find memory-intensive operations
let largeSnapshots = devTools.history.entries.filter { entry in
    entry.stateAfter.debugDescription.count > 1000
}
```

---

## Action Replay

### Recording Manual Actions

For non-provider state changes, record manually:

```swift
let devTools = DevToolsObserver()

// Before action
let beforeState = AnyCodable(currentAppState)

// Perform action
performUserAction()

// After action
let afterState = AnyCodable(newAppState)

// Record
devTools.recordAction(
    "userClicked_button",
    before: beforeState,
    after: afterState,
    computeTime: 0.5
)
```

### Replaying Sequences

```swift
// Replay all recorded history
await devTools.history.replay()

// Or replay specific range
for (idx, entry) in devTools.history.entries.enumerated() where idx < 10 {
    // Re-apply this state
    print("Replaying: \(entry.action ?? "init")")
}
```

---

## Reports and Export

### Generating Reports

```swift
let devTools = DevToolsObserver()

// Performance report
let perfReport = devTools.metrics.generateReport()
print(perfReport)

// Debug report
let debugReport = devTools.generateDebugReport()
print(debugReport)
```

### Exporting Data

```swift
// Export as JSON
let json = devTools.exportAsJSON()
print(json)

// Save to file
try json.write(
    toFile: "/tmp/devtools-export.json",
    atomically: true,
    encoding: .utf8
)

// Share with team
UIPasteboard.general.string = json
```

### History Export

```swift
// Export history separately
let historyJSON = devTools.history.export()

// Import history later
devTools.history.importJSON(historyJSON)
```

---

## Best Practices

### 1. Use DevTools in Development Only

```swift
#if DEBUG
let observers: [ProviderObserver] = [DevToolsObserver()]
#else
let observers: [ProviderObserver] = []
#endif
```

### 2. Monitor Performance Regularly

```swift
// Periodically check metrics
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    for metric in devTools.metrics.slowestProviders {
        if metric.isSlowProvider {
            print("⚠️ Slow provider detected: \(metric.providerName)")
        }
    }
}
```

### 3. Export Data for Analysis

```swift
// Save debug info before crashes
let report = devTools.generateDebugReport()
FileManager.default.createFile(
    atPath: "/tmp/debug.txt",
    contents: report.data(using: .utf8),
    attributes: nil
)
```

### 4. Name Your Providers

Use meaningful names for better debugging:

```swift
// Good - descriptive names
let userProvider = Provider(name: "user") { ... }
let cartTotalProvider = Provider(name: "cartTotal") { ... }

// Avoid - generic names
let p1 = Provider { ... }  // ❌ Not helpful
let provider = Provider { ... }  // ❌ Not helpful
```

### 5. Limit History Size for Long Sessions

```swift
var devTools = DevToolsObserver()
devTools.maxHistoryEntries = 50  // Reduce memory usage
devTools.maxMetricsRecords = 500  // Limit metrics
```

---

## Troubleshooting

### High Memory Usage

**Problem**: DevTools uses too much memory

**Solutions**:
```swift
// Reduce history size
devTools.maxHistoryEntries = 25

// Reduce metrics records
devTools.maxMetricsRecords = 250

// Disable state snapshots (less detailed inspection)
devTools.storeSnapshots = false

// Periodically clear
devTools.clearHistory()
```

### Missing State Changes

**Problem**: Some state changes not recorded

**Cause**: Provider names not set

**Solution**:
```swift
// Always set provider names
let myProvider = Provider(name: "myProvider") { ... }
```

### Performance Profiling Not Accurate

**Problem**: Metrics seem incorrect

**Solutions**:
```swift
// Ensure DevTools is properly initialized
let devTools = DevToolsObserver()
let container = ProviderContainer(observers: [devTools])

// Check that providers are named
print(devTools.metrics.allMetrics.count)  // Should be > 0
```

### Export File Too Large

**Problem**: Exported JSON is huge

**Solutions**:
```swift
// Clear history before export
devTools.clearHistory()

// Export only recent data
let recentEntries = devTools.history.entries.suffix(10)

// Or reset metrics
devTools.metrics.reset()
```

---

## API Reference

### DevToolsObserver

```swift
public final class DevToolsObserver: ProviderObserver {
    public var history: InMemoryStateHistory
    public var metrics: InMemoryPerformanceMetrics

    public var maxHistoryEntries: Int
    public var maxMetricsRecords: Int
    public var storeSnapshots: Bool
    public var debugLoggingEnabled: Bool

    public mutating func goBack() -> AnyCodable?
    public mutating func goForward() -> AnyCodable?
    public mutating func jumpToHistoryIndex(_ index: Int) -> AnyCodable?
    public func clearHistory()

    public func recordAction(
        _ action: String,
        before: AnyCodable,
        after: AnyCodable,
        computeTime: Double
    )

    public func generateDebugReport() -> String
    public func exportAsJSON() -> String
}
```

### StateHistory

```swift
public protocol StateHistory {
    var entries: [HistoryEntry] { get }
    var currentIndex: Int { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }

    mutating func record(action: String?, before: AnyCodable, after: AnyCodable, computeTime: Double)
    mutating func goBack() -> AnyCodable?
    mutating func goForward() -> AnyCodable?
    mutating func jumpTo(index: Int) -> AnyCodable?
    mutating func clear()

    func export() -> String
    mutating func importJSON(_ json: String) -> Bool
}
```

### PerformanceMetrics

```swift
public protocol PerformanceMetrics {
    var slowestProviders: [PerformanceData] { get }
    var mostUpdated: [PerformanceData] { get }
    var allMetrics: [PerformanceData] { get }

    func updateFrequency(for providerName: String) -> Double
    func computeTime(for providerName: String) -> Double
    func callCount(for providerName: String) -> Int
    func memoryUsage(for providerName: String) -> Int

    mutating func reset()
    func generateReport() -> String
    func recordUpdate(providerName: String, computeTime: Double, memoryBytes: Int)
}
```

---

## Related Documents

- [PHASE3_PREVIEW.md](PHASE3_PREVIEW.md) - Phase 3 planning and design
- [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md) - Architecture patterns
- [STATUS_REPORT.md](STATUS_REPORT.md) - Library status
- [API_STABILITY.md](API_STABILITY.md) - Stability levels

---

## Future Enhancements (Phase 3b+)

- [ ] Redux DevTools integration
- [ ] Live state inspector SwiftUI overlay
- [ ] Dependency graph visualization
- [ ] Real-time performance dashboard
- [ ] Action filtering and search
- [ ] Breakpoint support
- [ ] Time-travel with live preview

---

**Version**: 2.2.0-beta  
**Status**: In Development  
**Last Updated**: May 17, 2026  
**Next**: UI overlay implementation (Phase 3b)
