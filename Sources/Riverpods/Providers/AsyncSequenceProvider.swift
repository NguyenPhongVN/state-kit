import Foundation
import StateKit

// MARK: - AsyncSequenceProviderElement

/// Internal element managing an AsyncSequenceProvider's async sequence iteration.
///
/// `AsyncSequenceProviderElement` is responsible for:
/// - Creating and iterating the async sequence
/// - Receiving and caching each successive value
/// - Tracking error states
/// - Notifying dependents on each value change
/// - Managing iteration lifecycle (cancellation on disposal)
/// - Handling sequence completion
///
/// **Lifecycle:**
/// 1. Created: Provider accessed, async sequence iteration starts
/// 2. Loading: Sequence starts, no values yet, state = .loading()
/// 3. Iterating: Values received, state = .data(value) updated for each value
/// 4. Error: Sequence fails, state = .error(error)
/// 5. Disposed: Iteration cancelled, resources released
///
/// **Thread Safety:**
/// Confined to the MainActor. Sequence iteration happens on the main thread.
///
/// - Note: This is an internal implementation detail. Use AsyncSequenceProvider macro to create async sequence-based providers.
@MainActor
public final class AsyncSequenceProviderElement<T: Sendable, S: AsyncSequence>: ProviderElement<AsyncSequenceProvider<T, S>> where S.Element == T {

    // MARK: - Properties

    /// The task running the async sequence iteration
    private var task: Task<Void, Never>?

    // MARK: - Value Creation

    /// Starts iterating the async sequence and returns initial loading state.
    ///
    /// **Lifecycle:**
    /// 1. Creates the async sequence
    /// 2. Returns .loading() immediately
    /// 3. Iterates the sequence using `for try await`
    /// 4. On each value, updates state and notifies dependents
    /// 5. On error, updates to error state
    /// 6. On completion, keeps last value cached
    ///
    /// - Returns: AsyncValue representing the sequence's initial state
    public override func providerCreate() -> AsyncValue<T> {
        // Cancel any previous iteration
        task?.cancel()

        // Start new async sequence iteration
        task = Task { @MainActor in
            do {
                // Create the async sequence
                let sequence = provider.makeSequence(ref: self)

                // Iterate over sequence values
                for try await value in sequence {
                    if Task.isCancelled { return }

                    // Update state with new value
                    let oldState = self.stateBox?.value
                    self.stateBox?.value = .data(value)
                    self.notifyDependents()
                    self.container.notifyProviderUpdated(
                        provider: self.provider,
                        oldValue: oldState ?? .loading(),
                        newValue: .data(value)
                    )
                }
            } catch {
                if Task.isCancelled { return }

                // Handle sequence error
                let oldState = self.stateBox?.value
                self.stateBox?.value = .error(error, previousData: oldState?.value)
                self.notifyDependents()
                self.container.notifyProviderUpdated(
                    provider: self.provider,
                    oldValue: oldState ?? .loading(),
                    newValue: .error(error, previousData: oldState?.value)
                )
            }
        }

        // Cancel iteration when provider is disposed
        onDispose {
            self.task?.cancel()
        }

        // Return initial state
        if let lastValue = stateBox?.value.value {
            return .refreshing(lastValue)
        }
        return .loading()
    }
}

// MARK: - AsyncSequenceProvider

/// A provider that iterates an async sequence and emits values as they arrive.
///
/// `AsyncSequenceProvider` is designed for handling continuous sequences of data using
/// Swift's structured concurrency patterns. Use AsyncSequenceProvider when working with:
/// - Async sequence generators (URLSession.bytes, AsyncStream, etc.)
/// - Custom async sequences
/// - Streams created with modern async/await patterns
/// - Sequences that conform to AsyncSequence protocol
///
/// **Key Characteristics:**
/// - **Async-native**: Built on AsyncSequence protocol
/// - **Iterating**: Continuously iterates sequence values using `for try await`
/// - **Reactive**: Automatically updates cached value with each value emitted
/// - **Error-aware**: Tracks error states in AsyncValue
/// - **Cancellable**: Automatically cancels iteration when provider is disposed
/// - **Modern**: Uses Swift's structured concurrency
///
/// **Thread Safety:**
/// Confined to the MainActor. Sequence iteration happens on the main thread.
///
/// **State Progression:**
/// ```
/// Initial: .loading()
///      ↓
/// First value: .data(T)
///      ↓
/// More values: .data(T) [updated repeatedly]
///      ↓
/// Sequence error: .error(Error, previousData?)
///      ↓
/// Sequence completed: Last value cached
/// ```
///
/// **Comparison with StreamProvider:**
/// | Aspect | StreamProvider | AsyncSequenceProvider |
/// |--------|----------------|-----------------------|
/// | Framework | Combine | Async/Await |
/// | Protocol | Publisher | AsyncSequence |
/// | Use when | Already using Combine | Using modern async/await |
/// | Complexity | Medium | Low (structured concurrency) |
/// | Overhead | More overhead | Less overhead |
///
/// **When to Use:**
/// - Working with AsyncSequence implementations
/// - Modern async/await code patterns
/// - URLSession.bytes, WebSocket sequences
/// - Custom async generators
/// - Avoiding Combine dependency
///
/// **When NOT to Use:**
/// - Simple async operations (use `FutureProvider`)
/// - Using Combine extensively (use `StreamProvider`)
/// - Simple sync values (use `Provider`)
/// - Imperative state management (use `StateProvider`)
///
/// **Example: URLSession Bytes**
/// ```swift
/// @AsyncSequenceProvider
/// func downloadProgressProvider(ref: ProviderRef) -> AnyAsyncSequence<UInt64> {
///     let url = URL(string: "https://example.com/data")!
///     let (bytes, response) = try await URLSession.shared.bytes(from: url)
///
///     return bytes.map { _ in response.expectedContentLength }
///         .eraseToAnyAsyncSequence()
/// }
/// ```
///
/// **Example: Custom Async Generator**
/// ```swift
/// @AsyncSequenceProvider
/// func timerSequenceProvider(ref: ProviderRef) -> AsyncStream<Int> {
///     AsyncStream { continuation in
///         var count = 0
///         let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
///             continuation.yield(count)
///             count += 1
///         }
///
///         ref.onDispose {
///             timer.invalidate()
///         }
///     }
/// }
/// ```
///
/// **Example: Polling with AsyncSequence**
/// ```swift
/// @AsyncSequenceProvider
/// func locationSequenceProvider(ref: ProviderRef) -> AsyncStream<Location> {
///     AsyncStream { continuation in
///         Task {
///             while true {
///                 if Task.isCancelled { break }
///                 let location = try await locationManager.currentLocation()
///                 continuation.yield(location)
///                 try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
///             }
///             continuation.finish()
///         }
///     }
/// }
/// ```
///
/// - Important: AsyncSequenceProvider caches the latest value. Previous values are not retained.
/// - Note: The async sequence is created fresh each time the provider is accessed or invalidated.
/// - Warning: Ensure the sequence completes or fails; incomplete sequences prevent provider cleanup.
public struct AsyncSequenceProvider<T: Sendable, S: AsyncSequence>: ProviderProtocol, @unchecked Sendable where S.Element == T {

    // MARK: - Type Definition

    /// The state type is AsyncValue tracking the sequence's current value
    public typealias State = AsyncValue<T>

    // MARK: - Properties

    /// The closure that creates the async sequence
    private let _create: @MainActor (ProviderRef) -> S

    /// Unique identifier for this provider instance
    private let _id: AnyHashable

    /// Whether to automatically dispose when no longer listened to
    public let autoDispose: Bool

    /// Time in seconds before the cached value is invalidated
    public let cacheTime: TimeInterval

    /// Human-readable name for debugging
    public let name: String?

    // MARK: - Initialization

    /// Creates a new AsyncSequenceProvider with explicit configuration.
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - cacheTime: How long to cache the last value in seconds (default: 0)
    ///   - name: Optional debug name
    ///   - create: The closure that creates the async sequence
    ///
    /// **Example: AsyncStream**
    /// ```swift
    /// let timerProvider = AsyncSequenceProvider(
    ///     cacheTime: 60,
    ///     name: "timerProvider"
    /// ) { ref in
    ///     AsyncStream { continuation in
    ///         var count = 0
    ///         Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    ///             continuation.yield(count)
    ///             count += 1
    ///         }
    ///     }
    /// }
    /// ```
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ create: @escaping @MainActor (ProviderRef) -> S
    ) {
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
        self._id = UUID()
    }

    // MARK: - Internal Methods

    /// Creates the async sequence for iteration.
    ///
    /// - Parameter ref: The provider reference for dependency tracking
    /// - Returns: An async sequence emitting values
    @MainActor
    func makeSequence(ref: ProviderRef) -> S {
        _create(ref)
    }

    // MARK: - ProviderProtocol Conformance

    /// Creates an element to manage this provider's async sequence iteration
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        AsyncSequenceProviderElement(provider: self, container: container)
    }

    /// Hashes this provider using its unique identifier
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }

    /// Two AsyncSequenceProviders are equal if they have the same identifier
    public static func == (lhs: AsyncSequenceProvider, rhs: AsyncSequenceProvider) -> Bool {
        lhs._id == rhs._id
    }
}
