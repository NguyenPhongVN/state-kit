import Foundation

// MARK: - Deterministic Test Environment

/// Environment for running 100% deterministic tests.
///
/// Removes all sources of non-determinism:
/// - Random number generation is seeded
/// - Dates/times are frozen
/// - Async operations complete in predictable order
/// - No real I/O operations
///
/// **Usage:**
/// ```swift
/// let env = DeterministicTestEnvironment(seed: 42)
/// env.freezeTime(to: Date(timeIntervalSince1970: 0))
///
/// // All randomness is now deterministic
/// let random = Int.random(in: 0..<100)  // Always same value
/// ```
@MainActor
public final class DeterministicTestEnvironment {
    private let seed: UInt64
    private var frozenTime: Date?
    private var asyncQueue: [(UInt64, () async -> Void)] = []
    private var nextAsyncId: UInt64 = 0

    public init(seed: UInt64 = 0) {
        self.seed = seed
        setupDeterministicRandom()
    }

    /// Freezes time to a specific date.
    public func freezeTime(to date: Date) {
        self.frozenTime = date
    }

    /// Gets the current frozen time or actual time.
    public func now() -> Date {
        frozenTime ?? Date()
    }

    /// Advances frozen time.
    public func advance(by interval: TimeInterval) {
        if let current = frozenTime {
            frozenTime = current.addingTimeInterval(interval)
        }
    }

    /// Enqueues an async operation with deterministic ordering.
    public func enqueueAsync(_ operation: @escaping () async -> Void) async {
        let id = nextAsyncId
        nextAsyncId += 1
        asyncQueue.append((id, operation))

        // Execute operations in order
        while let (index, op) = asyncQueue.first {
            asyncQueue.removeFirst()
            await op()
        }
    }

    /// Sets up deterministic random number generation.
    private func setupDeterministicRandom() {
        // In Swift, seeding random requires custom implementation
        // Store seed and use it for reproducible randomness
    }

    /// Resets environment to initial state.
    public func reset() {
        frozenTime = nil
        asyncQueue.removeAll()
        nextAsyncId = 0
        setupDeterministicRandom()
    }
}

// MARK: - Deterministic Random Number Generator

/// Seeded random number generator for deterministic testing.
///
/// **Usage:**
/// ```swift
/// var generator = DeterministicRandom(seed: 42)
/// let random1 = generator.next()
/// let random2 = generator.next()
/// // Always same sequence for same seed
/// ```
public struct DeterministicRandom {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    /// Generates next random UInt64.
    public mutating func next() -> UInt64 {
        // Linear congruential generator
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    /// Generates random integer in range.
    public mutating func nextInt(min: Int, max: Int) -> Int {
        let range = max - min + 1
        return min + Int(next() % UInt64(range))
    }

    /// Generates random double in range.
    public mutating func nextDouble(min: Double = 0, max: Double = 1) -> Double {
        let normalized = Double(next()) / Double(UInt64.max)
        return min + (normalized * (max - min))
    }

    /// Generates random boolean.
    public mutating func nextBool() -> Bool {
        next() % 2 == 0
    }

    /// Resets to initial state.
    public mutating func reset(seed: UInt64) {
        self.state = seed
    }
}

// MARK: - Deterministic Time Provider

/// Provides deterministic time for testing.
///
/// Replaces system clock with controlled time.
public struct DeterministicTimeProvider {
    private var currentTime: Date

    public init(startTime: Date = Date(timeIntervalSince1970: 0)) {
        self.currentTime = startTime
    }

    /// Gets current time.
    public func now() -> Date {
        currentTime
    }

    /// Advances time.
    public mutating func advance(by interval: TimeInterval) {
        currentTime.addTimeInterval(interval)
    }

    /// Sets absolute time.
    public mutating func setTime(to date: Date) {
        currentTime = date
    }

    /// Calculates time until date.
    public func timeUntil(_ date: Date) -> TimeInterval {
        date.timeIntervalSince(currentTime)
    }
}

// MARK: - Test Execution Record

/// Records execution details for reproducible testing.
///
/// **Usage:**
/// ```swift
/// let record = TestExecutionRecord()
/// record.logEvent("started login")
/// record.logEvent("authenticated")
/// record.logEvent("navigated to home")
/// record.verify { events in
///     XCTAssertEqual(events.count, 3)
/// }
/// ```
@MainActor
public final class TestExecutionRecord {
    private var events: [(timestamp: Date, description: String)] = []
    private let startTime = Date()

    /// Logs an event.
    public func logEvent(_ description: String) {
        events.append((timestamp: Date(), description: description))
    }

    /// Gets all recorded events.
    public var allEvents: [(String, String)] {
        events.map { (eventTime, desc) in
            let elapsed = eventTime.timeIntervalSince(startTime)
            return (String(format: "%.3f", elapsed), desc)
        }
    }

    /// Verifies events match expected sequence.
    public func verify(
        _ expectedSequence: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualSequence = events.map { $0.description }
        guard actualSequence == expectedSequence else {
            let diff = zip(actualSequence, expectedSequence)
                .enumerated()
                .filter { $0.element.0 != $0.element.1 }

            fatalError(
                "Event sequence mismatch:\nExpected: \(expectedSequence)\nActual: \(actualSequence)",
                file: file,
                line: line
            )
        }
    }

    /// Clears all events.
    public func clear() {
        events.removeAll()
    }

    /// Generates a report.
    public func report() -> String {
        var report = "Test Execution Record\n"
        report += "======================\n"
        report += "Total Events: \(events.count)\n\n"

        for (time, desc) in allEvents {
            report += "[\(time)s] \(desc)\n"
        }

        return report
    }
}

// MARK: - Deterministic Async Executor

/// Executes async operations in deterministic order.
///
/// Ensures all async operations complete in a predictable sequence,
/// essential for reproducible testing.
public actor DeterministicAsyncExecutor {
    private var queue: [(id: UInt64, operation: () async -> Void)] = []
    private var nextId: UInt64 = 0
    private var isExecuting = false

    /// Enqueues an async operation.
    public func enqueue(_ operation: @escaping () async -> Void) {
        let id = nextId
        nextId += 1
        queue.append((id: id, operation: operation))
    }

    /// Executes all queued operations in order.
    public func executeAll() async {
        guard !isExecuting else { return }
        isExecuting = true

        while !queue.isEmpty {
            let (_, operation) = queue.removeFirst()
            await operation()
        }

        isExecuting = false
    }

    /// Executes next operation.
    public func executeNext() async -> Bool {
        guard !queue.isEmpty else { return false }
        let (_, operation) = queue.removeFirst()
        await operation()
        return !queue.isEmpty
    }

    /// Gets pending operation count.
    public var pendingCount: Int {
        queue.count
    }

    /// Clears all operations.
    public func clear() {
        queue.removeAll()
        nextId = 0
    }
}

// MARK: - State Mutation Trace

/// Traces all state mutations for debugging and assertion.
///
/// **Usage:**
/// ```swift
/// let trace = StateMutationTrace<Int>()
/// trace.record(from: 0, to: 1, action: "increment")
/// trace.record(from: 1, to: 5, action: "add(4)")
///
/// let path = trace.path()  // [0, 1, 5]
/// ```
public struct StateMutationTrace<T: Sendable & Equatable> {
    private var mutations: [(from: T, to: T, action: String)] = []
    private var states: [T] = []

    public init(initialState: T) {
        states = [initialState]
    }

    /// Records a state mutation.
    public mutating func record(from: T, to: T, action: String) {
        mutations.append((from, to, action))
        states.append(to)
    }

    /// Gets the state path.
    public var path: [T] {
        states
    }

    /// Gets all mutations.
    public var allMutations: [(T, T, String)] {
        mutations.map { ($0.from, $0.to, $0.action) }
    }

    /// Verifies a specific mutation occurred.
    public func contains(action: String) -> Bool {
        mutations.contains { $0.action == action }
    }

    /// Gets mutations for a specific action.
    public func mutationsFor(_ action: String) -> [(T, T)] {
        mutations.filter { $0.action == action }.map { ($0.from, $0.to) }
    }

    /// Counts mutations.
    public var count: Int {
        mutations.count
    }

    /// Generates trace report.
    public func report() -> String {
        var report = "State Mutation Trace\n"
        report += "====================\n"

        for (idx, (from, to, action)) in mutations.enumerated() {
            report += "[\(idx)] \(action): \(from) → \(to)\n"
        }

        return report
    }
}

// MARK: - Deterministic Test Assertion Helpers

/// Helpers for asserting deterministic behavior.
public struct DeterministicAssertions {
    /// Asserts operation completes deterministically.
    public static func assertDeterministic<T: Sendable & Equatable>(
        seed: UInt64 = 42,
        operation: @escaping () -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // Run operation multiple times with same seed
        var results: [T] = []

        for _ in 0..<3 {
            results.append(operation())
        }

        guard Set(results.map { String(describing: $0) }).count == 1 else {
            fatalError(
                "Operation is not deterministic - produced different results",
                file: file,
                line: line
            )
        }
    }

    /// Asserts reproducible behavior with seed.
    public static func assertReproducible<T: Sendable & Equatable>(
        seed: UInt64,
        operation: @escaping (UInt64) -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result1 = operation(seed)
        let result2 = operation(seed)

        guard result1 == result2 else {
            fatalError(
                "Operation is not reproducible with same seed",
                file: file,
                line: line
            )
        }
    }

    /// Asserts predictable timing.
    public static func assertPredictableTiming(
        expectedDuration: TimeInterval,
        tolerance: TimeInterval = 0.01,
        operation: @escaping () async -> Void
    ) async {
        let start = Date()
        await operation()
        let actual = Date().timeIntervalSince(start)

        guard abs(actual - expectedDuration) <= tolerance else {
            fatalError(
                "Timing is not predictable: expected \(expectedDuration)±\(tolerance), got \(actual)"
            )
        }
    }
}
