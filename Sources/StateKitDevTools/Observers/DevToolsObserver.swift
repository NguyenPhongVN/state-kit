import Foundation
import Riverpods

// MARK: - DevTools Observer

/// A comprehensive provider observer that enables time-travel debugging and performance profiling.
///
/// Integrates state history recording and performance tracking, enabling developers to:
/// - Record all state changes
/// - Track performance metrics in real-time
/// - Debug state evolution over time
/// - Identify performance bottlenecks
///
/// **Setup:**
/// ```swift
/// let observer = DevToolsObserver()
/// let container = ProviderContainer(observers: [observer])
///
/// // Later, access history and metrics
/// let history = observer.history
/// let metrics = observer.metrics
/// ```
///
/// **Memory Considerations**:
/// - History is limited to recent entries (configurable)
/// - Performance metrics use rolling window (configurable)
/// - Consider disabling in production for memory efficiency
///
/// - Important: Only use in DEBUG mode for production builds
/// - Warning: Recording state snapshots uses memory proportional to state size
@MainActor
public final class DevToolsObserver: ProviderObserver {
    // MARK: - Properties

    /// State history tracker.
    public private(set) var history: InMemoryStateHistory

    /// Performance metrics tracker.
    public private(set) var metrics: InMemoryPerformanceMetrics

    /// Records computation start times for performance tracking.
    private var computeStartTimes: [String: Date] = [:]

    /// Maximum history entries (default: 100).
    public var maxHistoryEntries: Int {
        get { history.maxEntries }
        set { history.maxEntries = newValue }
    }

    /// Maximum performance records per provider (default: 1000).
    public var maxMetricsRecords: Int {
        get { metrics.maxRecordsPerProvider }
        set { metrics.maxRecordsPerProvider = newValue }
    }

    /// Whether to store full state snapshots in history.
    public var storeSnapshots: Bool {
        get { history.storeSnapshots }
        set { history.storeSnapshots = newValue }
    }

    /// Debug logging enabled.
    public var debugLoggingEnabled: Bool = false

    // MARK: - Initialization

    public init() {
        self.history = InMemoryStateHistory()
        self.metrics = InMemoryPerformanceMetrics()
    }

    // MARK: - ProviderObserver Implementation

    public func didAddProvider<P: ProviderProtocol>(
        _ provider: P,
        value: P.State,
        container: ProviderContainer
    ) {
        if debugLoggingEnabled {
            print("[DevTools] Added provider: \(provider.name ?? "Unknown")")
        }
    }

    public func didUpdateProvider<P: ProviderProtocol>(
        _ provider: P,
        previousValue: P.State,
        newValue: P.State,
        container: ProviderContainer
    ) {
        let providerName = provider.name ?? "Unknown"

        // Record in history
        if history.storeSnapshots {
            let before = AnyCodable(previousValue)
            let after = AnyCodable(newValue)
            let computeTime = computeTime(for: providerName)
            history.record(
                action: nil,
                before: before,
                after: after,
                computeTime: computeTime
            )
        }

        if debugLoggingEnabled {
            print("[DevTools] Updated provider: \(providerName)")
        }
    }

    public func didDisposeProvider<P: ProviderProtocol>(
        _ provider: P,
        container: ProviderContainer
    ) {
        let providerName = provider.name ?? "Unknown"

        // Clean up timing data
        computeStartTimes.removeValue(forKey: providerName)

        if debugLoggingEnabled {
            print("[DevTools] Disposed provider: \(providerName)")
        }
    }

    // MARK: - Performance Tracking

    /// Records the start of a provider computation.
    ///
    /// Call this before computing a provider value.
    ///
    /// - Parameter providerName: The provider being computed
    public func startComputation(providerName: String) {
        computeStartTimes[providerName] = Date()
    }

    /// Records the end of a provider computation.
    ///
    /// Call this after computing a provider value.
    ///
    /// - Parameters:
    ///   - providerName: The provider that was computed
    ///   - memoryBytes: Estimated size of the computed value
    public func endComputation(providerName: String, memoryBytes: Int = 0) {
        let computeTime = self.computeTime(for: providerName)
        metrics.recordUpdate(
            providerName: providerName,
            computeTime: computeTime,
            memoryBytes: memoryBytes
        )
        computeStartTimes.removeValue(forKey: providerName)
    }

    /// Gets the elapsed time since computation started.
    private func computeTime(for providerName: String) -> Double {
        guard let startTime = computeStartTimes[providerName] else { return 0 }
        return Date().timeIntervalSince(startTime) * 1000  // Convert to milliseconds
    }

    // MARK: - History Management

    /// Records a manual action with its state change.
    ///
    /// Use this to record external actions or non-provider state changes.
    ///
    /// - Parameters:
    ///   - action: The action name
    ///   - before: State before the action
    ///   - after: State after the action
    ///   - computeTime: Time taken (in milliseconds)
    public func recordAction(
        _ action: String,
        before: AnyCodable,
        after: AnyCodable,
        computeTime: Double = 0
    ) {
        history.record(
            action: action,
            before: before,
            after: after,
            computeTime: computeTime
        )
    }

    /// Travels back in history.
    ///
    /// - Returns: The state at the previous position
    @discardableResult
    public mutating func goBack() -> AnyCodable? {
        history.goBack()
    }

    /// Travels forward in history.
    ///
    /// - Returns: The state at the next position
    @discardableResult
    public mutating func goForward() -> AnyCodable? {
        history.goForward()
    }

    /// Jumps to a specific point in history.
    ///
    /// - Parameter index: The history entry index
    /// - Returns: The state at that point
    @discardableResult
    public mutating func jumpToHistoryIndex(_ index: Int) -> AnyCodable? {
        history.jumpTo(index: index)
    }

    /// Clears all history.
    public func clearHistory() {
        history.clear()
    }

    // MARK: - Reporting

    /// Generates a comprehensive debug report.
    public func generateDebugReport() -> String {
        var report = "=== StateKit DevTools Report ===\n\n"

        // History section
        report += "History:\n"
        report += "  Total Entries: \(history.entries.count)\n"
        report += "  Current Index: \(history.currentIndex)\n"
        report += "  Can Go Back: \(history.canGoBack)\n"
        report += "  Can Go Forward: \(history.canGoForward)\n\n"

        // Metrics section
        report += metrics.generateReport()

        return report
    }

    /// Exports all debugging data as JSON.
    ///
    /// Useful for sharing debugging information or analysis.
    ///
    /// - Returns: JSON string with history and metrics
    public func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        let data: [String: Any] = [
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "history": history.export(),
            "performance_metrics": metrics.allMetrics.map { data in
                [
                    "provider": data.providerName,
                    "update_frequency": String(format: "%.2f", data.updateFrequency),
                    "average_compute_time_ms": String(format: "%.2f", data.averageComputeTime),
                    "total_calls": data.totalCallCount,
                    "estimated_memory_bytes": data.estimatedMemory
                ]
            }
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}

// MARK: - Console Logger Observer (Convenience)

/// A simple console logging observer for debugging.
///
/// Logs state changes and important events to the console.
///
/// **Usage:**
/// ```swift
/// let container = ProviderContainer(observers: [ConsoleLoggerObserver()])
/// ```
@MainActor
public final class ConsoleLoggerObserver: ProviderObserver {
    /// Prefix for all log messages.
    public let logPrefix: String

    /// Whether to log provider additions.
    public var logAdditions: Bool = false

    /// Whether to log provider updates.
    public var logUpdates: Bool = true

    /// Whether to log provider disposals.
    public var logDisposals: Bool = false

    public init(prefix: String = "[StateKit]") {
        self.logPrefix = prefix
    }

    public func didAddProvider<P: ProviderProtocol>(
        _ provider: P,
        value: P.State,
        container: ProviderContainer
    ) {
        guard logAdditions else { return }
        print("\(logPrefix) [+] \(provider.name ?? "Provider") initialized")
    }

    public func didUpdateProvider<P: ProviderProtocol>(
        _ provider: P,
        previousValue: P.State,
        newValue: P.State,
        container: ProviderContainer
    ) {
        guard logUpdates else { return }
        print("\(logPrefix) [→] \(provider.name ?? "Provider") updated")
    }

    public func didDisposeProvider<P: ProviderProtocol>(
        _ provider: P,
        container: ProviderContainer
    ) {
        guard logDisposals else { return }
        print("\(logPrefix) [-] \(provider.name ?? "Provider") disposed")
    }
}
