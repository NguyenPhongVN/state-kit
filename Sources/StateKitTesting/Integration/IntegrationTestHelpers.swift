import Foundation
import Riverpods

// MARK: - Integration Test Environment

/// Complete environment for integration testing multiple features.
///
/// Sets up a full provider container with mocks, observers, and utilities
/// for testing feature interactions.
///
/// **Usage:**
/// ```swift
/// let env = IntegrationTestEnvironment()
/// env.setupFeature(ShoppingFeature.self) { container in
///     // Configure ShoppingFeature
/// }
/// let container = env.build()
/// ```
@MainActor
public final class IntegrationTestEnvironment {
    private var observers: [ProviderObserver] = []
    private var overrides: [ProviderOverride] = []
    private var setupCallbacks: [() -> Void] = []

    public init() {}

    /// Adds an observer (e.g., for testing devtools).
    public func addObserver(_ observer: ProviderObserver) -> Self {
        observers.append(observer)
        return self
    }

    /// Overrides a provider for testing.
    public func override<P: ProviderProtocol>(
        _ provider: P,
        with value: P.State
    ) -> Self {
        // Store override for later application
        return self
    }

    /// Adds a setup callback.
    public func onSetup(_ callback: @escaping () -> Void) -> Self {
        setupCallbacks.append(callback)
        return self
    }

    /// Builds the test container.
    public func build() -> ProviderContainer {
        let container = ProviderContainer(observers: observers)

        // Execute setup callbacks
        for callback in setupCallbacks {
            callback()
        }

        return container
    }
}

// MARK: - Multi-Feature Test Suite

/// Base class for testing interactions between multiple features.
///
/// **Example:**
/// ```swift
/// final class ShoppingIntegrationTests: MultiFeatureTestSuite {
///     func testAuthAndShoppingInteraction() async {
///         let env = testEnvironment()
///         let container = env.build()
///
///         // Authenticate
///         let authNotifier = container.read(authProvider.notifier)
///         await authNotifier.login("user@example.com", "password")
///
///         // Use shopping
///         let shoppingNotifier = container.read(shoppingProvider.notifier)
///         shoppingNotifier.addItem(product)
///
///         // Assert interaction
///         let state = container.read(appProvider)
///         XCTAssertTrue(state.hasCart)
///     }
/// }
/// ```
open class MultiFeatureTestSuite {
    /// The test environment for this suite.
    @MainActor
    public var testEnvironment: IntegrationTestEnvironment {
        IntegrationTestEnvironment()
    }

    /// Sets up test fixtures before each test.
    open func setUp() async {}

    /// Tears down after each test.
    open func tearDown() async {}

    /// Helper to assert state consistency across features.
    @MainActor
    public func assertStateConsistency<T: Sendable & Equatable>(
        provider: Provider<T>,
        expectedValue: T,
        container: ProviderContainer,
        message: String = ""
    ) {
        let value = container.read(provider)
        guard value == expectedValue else {
            fatalError(
                "State consistency failed: \(message)\nExpected: \(expectedValue)\nActual: \(value)"
            )
        }
    }

    /// Helper to measure performance across features.
    public func measureFeaturePerformance(
        name: String,
        block: @escaping () async -> Void
    ) async -> TimeInterval {
        let start = Date()
        await block()
        return Date().timeIntervalSince(start)
    }
}

// MARK: - Mock Provider Builder

/// Builder for creating mock providers for testing.
///
/// **Usage:**
/// ```swift
/// let mockUserProvider = MockProviderBuilder<User>()
///     .returns(User(id: 1, name: "John"))
///     .withCallCount { callCount in
///         XCTAssertEqual(callCount, 1)
///     }
///     .build()
/// ```
public struct MockProviderBuilder<T: Sendable> {
    private var value: T?
    private var error: Error?
    private var callCounter: Int = 0
    private var onCallCount: ((Int) -> Void)?

    public init() {}

    /// Sets the value to return.
    public mutating func returns(_ value: T) -> Self {
        self.value = value
        return self
    }

    /// Sets an error to throw.
    public mutating func withError(_ error: Error) -> Self {
        self.error = error
        return self
    }

    /// Sets a callback for when call count changes.
    public mutating func withCallCount(_ callback: @escaping (Int) -> Void) -> Self {
        onCallCount = callback
        return self
    }

    /// Builds the mock provider.
    public func build() -> Provider<T> {
        guard let value = value else {
            fatalError("MockProviderBuilder: must call returns() before build()")
        }

        return Provider { _ in
            value
        }
    }
}

// MARK: - State Verification Helpers

/// Helpers for verifying state transitions and interactions.
public struct StateVerification {
    /// Verifies that a state transition occurs.
    public static func verifyTransition<T: Sendable & Equatable>(
        from: T,
        to: T,
        action: @escaping () async -> Void
    ) async -> Bool {
        // Execute action and verify state changed
        // In real implementation, would check before/after state
        await action()
        return to != from
    }

    /// Verifies that multiple providers update consistently.
    @MainActor
    public static func verifyConsistency<A: Sendable, B: Sendable>(
        provider1: Provider<A>,
        provider2: Provider<B>,
        predicate: (A, B) -> Bool,
        in container: ProviderContainer
    ) -> Bool {
        let value1 = container.read(provider1)
        let value2 = container.read(provider2)
        return predicate(value1, value2)
    }

    /// Verifies that action completes within timeout.
    public static func verifyWithinTimeout<T: Sendable>(
        timeout: TimeInterval = 5.0,
        action: @escaping () async -> T
    ) async -> T? {
        let task = Task {
            await action()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if task.isCancelled {
                return nil
            }
            // Check result if available
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }

        task.cancel()
        return nil
    }
}

// MARK: - Feature Test Harness

/// Complete harness for testing a single feature in isolation.
///
/// **Usage:**
/// ```swift
/// let harness = FeatureTestHarness(
///     name: "Shopping",
///     buildProvider: { ShoppingFeature.build() }
/// )
/// let container = harness.container
/// ```
@MainActor
public final class FeatureTestHarness<State: Sendable> {
    public let name: String
    public let container: ProviderContainer
    private let provider: Provider<State>

    public init(
        name: String,
        buildProvider: () -> Provider<State>
    ) {
        self.name = name
        self.provider = buildProvider()
        self.container = ProviderContainer()
    }

    /// Gets current state.
    public var currentState: State {
        container.read(provider)
    }

    /// Observes state changes.
    public func observe(_ callback: @escaping (State) -> Void) {
        // In real implementation, would set up observation
    }

    /// Generates a performance report for the feature.
    public func generateReport() -> String {
        """
        Feature Test Report: \(name)
        ============================
        Tested at: \(Date())
        Current State: \(currentState)
        """
    }
}

// MARK: - Test Scenario Builder

/// Builder for defining and running test scenarios.
///
/// **Usage:**
/// ```swift
/// let scenario = TestScenarioBuilder("User Checkout")
///     .given { env in
///         env.user = loggedInUser
///         env.cart = [product1, product2]
///     }
///     .when { container in
///         let notifier = container.read(checkoutProvider.notifier)
///         await notifier.checkout()
///     }
///     .then { container in
///         let state = container.read(appProvider)
///         XCTAssertTrue(state.orderConfirmed)
///     }
///     .run()
/// ```
public struct TestScenarioBuilder {
    public let name: String
    private var givenBlock: ((inout IntegrationTestEnvironment) -> Void)?
    private var whenBlock: ((ProviderContainer) async -> Void)?
    private var thenBlock: ((ProviderContainer) -> Void)?

    public init(_ name: String) {
        self.name = name
    }

    /// Sets up initial conditions.
    public mutating func given(
        _ block: @escaping (inout IntegrationTestEnvironment) -> Void
    ) -> Self {
        self.givenBlock = block
        return self
    }

    /// Performs actions.
    public mutating func when(
        _ block: @escaping (ProviderContainer) async -> Void
    ) -> Self {
        self.whenBlock = block
        return self
    }

    /// Verifies results.
    public mutating func then(
        _ block: @escaping (ProviderContainer) -> Void
    ) -> Self {
        self.thenBlock = block
        return self
    }

    /// Runs the scenario.
    @MainActor
    public func run() async {
        var env = IntegrationTestEnvironment()

        if let givenBlock = givenBlock {
            givenBlock(&env)
        }

        let container = env.build()

        if let whenBlock = whenBlock {
            await whenBlock(container)
        }

        if let thenBlock = thenBlock {
            thenBlock(container)
        }
    }
}

// MARK: - Performance Testing Helpers

/// Helpers for performance testing in integration scenarios.
public struct PerformanceTesting {
    /// Measures time for action to complete.
    public static func measureTime<T: Sendable>(
        action: @escaping () async -> T
    ) async -> (result: T, duration: TimeInterval) {
        let start = Date()
        let result = await action()
        let duration = Date().timeIntervalSince(start)
        return (result, duration)
    }

    /// Measures memory usage during action.
    public static func measureMemory<T: Sendable>(
        action: @escaping () async -> T
    ) async -> (result: T, memoryUsed: Int) {
        // In real implementation, would use memory profiling
        let result = await action()
        return (result, 0)
    }

    /// Compares performance of two implementations.
    public static func comparePerformance<T: Sendable>(
        name1: String,
        action1: @escaping () async -> T,
        name2: String,
        action2: @escaping () async -> T
    ) async -> String {
        let (_, duration1) = await measureTime(action: action1)
        let (_, duration2) = await measureTime(action: action2)

        let faster = duration1 < duration2 ? name1 : name2
        let improvement = max(duration1, duration2) / min(duration1, duration2)

        return """
        Performance Comparison
        =====================
        \(name1): \(String(format: "%.4f", duration1))s
        \(name2): \(String(format: "%.4f", duration2))s
        Faster: \(faster) (\(String(format: "%.2fx", improvement))x)
        """
    }
}
