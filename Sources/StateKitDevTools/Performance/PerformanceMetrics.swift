import Foundation

// MARK: - Performance Metrics Protocol

/// Tracks performance metrics across providers in real-time.
///
/// Enables developers to:
/// - Identify slow providers
/// - Track update frequency
/// - Monitor memory usage
/// - Profile compute times
/// - Optimize hot paths
///
/// **Example Usage:**
/// ```swift
/// let metrics = container.performanceMetrics
///
/// // Find slowest providers
/// for data in metrics.slowestProviders {
///     print("\(data.providerName): \(data.averageComputeTime)ms")
/// }
///
/// // Track specific provider
/// let updateFreq = metrics.updateFrequency(for: myProvider)
/// let computeTime = metrics.computeTime(for: myProvider)
///
/// // Generate report
/// let report = metrics.generateReport()
/// ```
///
/// **Thread Safety**: Not thread-safe. Access from main thread only.
public protocol PerformanceMetrics {
    /// Top 10 slowest providers by average compute time.
    var slowestProviders: [PerformanceData] { get }

    /// Top 10 most frequently updated providers.
    var mostUpdated: [PerformanceData] { get }

    /// All tracked provider metrics.
    var allMetrics: [PerformanceData] { get }

    /// Gets update frequency for a specific provider (in Hz).
    ///
    /// - Parameter providerName: The provider identifier
    /// - Returns: Updates per second, or 0 if not found
    func updateFrequency(for providerName: String) -> Double

    /// Gets average compute time for a provider (in milliseconds).
    ///
    /// - Parameter providerName: The provider identifier
    /// - Returns: Average compute time, or 0 if not found
    func computeTime(for providerName: String) -> Double

    /// Gets total call count for a provider.
    ///
    /// - Parameter providerName: The provider identifier
    /// - Returns: Number of times the provider was computed
    func callCount(for providerName: String) -> Int

    /// Estimates memory usage of a provider's state (in bytes).
    ///
    /// - Parameter providerName: The provider identifier
    /// - Returns: Estimated memory usage
    func memoryUsage(for providerName: String) -> Int

    /// Resets all performance data.
    mutating func reset()

    /// Generates a performance report.
    ///
    /// - Returns: Formatted string with performance analysis
    func generateReport() -> String

    /// Records a provider update.
    ///
    /// - Parameters:
    ///   - providerName: The provider identifier
    ///   - computeTime: Time taken to compute in milliseconds
    ///   - memoryBytes: Estimated state size in bytes
    func recordUpdate(providerName: String, computeTime: Double, memoryBytes: Int)
}

// MARK: - Performance Data

/// Aggregated performance data for a single provider.
public struct PerformanceData: Sendable, Comparable {
    /// The provider's identifier.
    public let providerName: String

    /// How often the provider is updated (in Hz).
    public let updateFrequency: Double

    /// Average time to compute the provider's value (in milliseconds).
    public let averageComputeTime: Double

    /// Total number of times the provider has been computed.
    public let totalCallCount: Int

    /// Estimated memory used by the provider's state (in bytes).
    public let estimatedMemory: Int

    /// Minimum compute time seen (in milliseconds).
    public let minComputeTime: Double

    /// Maximum compute time seen (in milliseconds).
    public let maxComputeTime: Double

    /// Total compute time across all calls (in milliseconds).
    public let totalComputeTime: Double

    /// When this provider was first accessed.
    public let firstAccessTime: Date

    /// When this provider was last updated.
    public let lastUpdateTime: Date

    public init(
        providerName: String,
        updateFrequency: Double,
        averageComputeTime: Double,
        totalCallCount: Int,
        estimatedMemory: Int,
        minComputeTime: Double,
        maxComputeTime: Double,
        totalComputeTime: Double,
        firstAccessTime: Date,
        lastUpdateTime: Date
    ) {
        self.providerName = providerName
        self.updateFrequency = updateFrequency
        self.averageComputeTime = averageComputeTime
        self.totalCallCount = totalCallCount
        self.estimatedMemory = estimatedMemory
        self.minComputeTime = minComputeTime
        self.maxComputeTime = maxComputeTime
        self.totalComputeTime = totalComputeTime
        self.firstAccessTime = firstAccessTime
        self.lastUpdateTime = lastUpdateTime
    }

    /// Compares by average compute time (slowest first).
    public static func < (lhs: PerformanceData, rhs: PerformanceData) -> Bool {
        lhs.averageComputeTime > rhs.averageComputeTime
    }

    /// Whether this provider's performance is concerning.
    public var isSlowProvider: Bool {
        averageComputeTime > 50.0  // > 50ms
    }

    /// Whether this provider is frequently updated.
    public var isFrequentlyUpdated: Bool {
        updateFrequency > 10.0  // > 10 Hz
    }

    /// Performance rating (0-100, higher is better).
    public var performanceScore: Int {
        let computeScore = max(0, 100 - Int(averageComputeTime * 2))
        let frequencyPenalty = max(0, Int(updateFrequency - 10) * 2)
        return max(0, computeScore - frequencyPenalty)
    }
}

// MARK: - Update Record (Internal)

struct UpdateRecord {
    let timestamp: Date
    let computeTime: Double
    let memoryBytes: Int
}

// MARK: - Default Implementation

/// Default in-memory implementation of PerformanceMetrics.
public struct InMemoryPerformanceMetrics: PerformanceMetrics {
    private var metrics: [String: [UpdateRecord]] = [:]
    private var firstAccessTimes: [String: Date] = [:]
    private var lastUpdateTimes: [String: Date] = [:]

    /// Maximum number of records per provider (default: 1000).
    public var maxRecordsPerProvider: Int = 1000

    public var slowestProviders: [PerformanceData] {
        allMetrics.sorted().prefix(10).map { $0 }
    }

    public var mostUpdated: [PerformanceData] {
        allMetrics.sorted { $0.updateFrequency > $1.updateFrequency }.prefix(10).map { $0 }
    }

    public var allMetrics: [PerformanceData] {
        metrics.compactMap { providerName, records in
            guard !records.isEmpty else { return nil }

            let computeTimes = records.map { $0.computeTime }
            let totalTime = computeTimes.reduce(0, +)
            let avgTime = totalTime / Double(records.count)
            let minTime = computeTimes.min() ?? 0
            let maxTime = computeTimes.max() ?? 0

            let memoryBytes = (records.map { $0.memoryBytes }.reduce(0, +)) / max(1, records.count)
            let timespan = lastUpdateTimes[providerName]?.timeIntervalSince(
                firstAccessTimes[providerName] ?? Date()
            ) ?? 0
            let frequency = timespan > 0 ? Double(records.count) / timespan : 0

            return PerformanceData(
                providerName: providerName,
                updateFrequency: frequency,
                averageComputeTime: avgTime,
                totalCallCount: records.count,
                estimatedMemory: memoryBytes,
                minComputeTime: minTime,
                maxComputeTime: maxTime,
                totalComputeTime: totalTime,
                firstAccessTime: firstAccessTimes[providerName] ?? Date(),
                lastUpdateTime: lastUpdateTimes[providerName] ?? Date()
            )
        }
    }

    public func updateFrequency(for providerName: String) -> Double {
        allMetrics.first(where: { $0.providerName == providerName })?.updateFrequency ?? 0
    }

    public func computeTime(for providerName: String) -> Double {
        allMetrics.first(where: { $0.providerName == providerName })?.averageComputeTime ?? 0
    }

    public func callCount(for providerName: String) -> Int {
        allMetrics.first(where: { $0.providerName == providerName })?.totalCallCount ?? 0
    }

    public func memoryUsage(for providerName: String) -> Int {
        allMetrics.first(where: { $0.providerName == providerName })?.estimatedMemory ?? 0
    }

    public mutating func recordUpdate(
        providerName: String,
        computeTime: Double,
        memoryBytes: Int
    ) {
        if firstAccessTimes[providerName] == nil {
            firstAccessTimes[providerName] = Date()
        }

        let record = UpdateRecord(
            timestamp: Date(),
            computeTime: computeTime,
            memoryBytes: memoryBytes
        )

        if metrics[providerName] == nil {
            metrics[providerName] = []
        }

        metrics[providerName]?.append(record)
        lastUpdateTimes[providerName] = Date()

        // Limit record size
        if let count = metrics[providerName]?.count, count > maxRecordsPerProvider {
            metrics[providerName] = Array(metrics[providerName]!.suffix(maxRecordsPerProvider))
        }
    }

    public mutating func reset() {
        metrics = [:]
        firstAccessTimes = [:]
        lastUpdateTimes = [:]
    }

    public func generateReport() -> String {
        var report = "Performance Report\n"
        report += "==================\n\n"

        // Overall stats
        let totalUpdates = metrics.values.reduce(0) { $0 + $1.count }
        let totalTime = metrics.values.flatMap { $0.map { $0.computeTime } }
            .reduce(0, +)

        report += "Overall Statistics:\n"
        report += "  Total Updates: \(totalUpdates)\n"
        report += "  Total Compute Time: \(String(format: "%.2f", totalTime))ms\n"
        report += "  Average Update Time: \(String(format: "%.2f", totalUpdates > 0 ? totalTime / Double(totalUpdates) : 0))ms\n\n"

        // Slowest providers
        report += "Slowest Providers:\n"
        for (idx, data) in slowestProviders.enumerated() {
            report += "  \(idx + 1). \(data.providerName)\n"
            report += "     Avg: \(String(format: "%.2f", data.averageComputeTime))ms"
            report += " | Min: \(String(format: "%.2f", data.minComputeTime))ms"
            report += " | Max: \(String(format: "%.2f", data.maxComputeTime))ms\n"
        }

        report += "\n"

        // Most updated providers
        report += "Most Frequently Updated:\n"
        for (idx, data) in mostUpdated.enumerated() {
            report += "  \(idx + 1). \(data.providerName): \(String(format: "%.1f", data.updateFrequency)) Hz\n"
        }

        report += "\nEnd Report\n"
        return report
    }
}
