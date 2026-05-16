import Foundation
import StateKit
import Observation

// MARK: - FutureProviderElement

/// Internal element managing a FutureProvider's one-shot async operation.
///
/// `FutureProviderElement` is responsible for:
/// - Starting and managing a single async operation
/// - Tracking the async operation's lifecycle (loading → data/error)
/// - Notifying dependents when the operation completes
/// - Handling cancellation when the provider is disposed
/// - Resolving continuations for awaitable access
///
/// **Lifecycle:**
/// 1. Created: Provider accessed for first time
/// 2. Loading: Async operation starts, state = .loading()
/// 3. Success: Operation completes with value, state = .data(value)
/// 4. Error: Operation fails, state = .error(error)
/// 5. Disposed: Operation cancelled, continuations released
///
/// **Thread Safety:**
/// Confined to the MainActor. All operations occur on the main thread.
///
/// - Note: This is an internal implementation detail. Use FutureProvider macro to create async one-shot providers.
@MainActor
public final class FutureProviderElement<T: Sendable>: ProviderElement<FutureProvider<T>> {

    // MARK: - Properties

    /// Continuations waiting for the async operation to complete
    ///
    /// When the async operation completes, all waiting continuations are resolved.
    /// This allows multiple consumers to await the same operation.
    private var continuations: [CheckedContinuation<T, Error>] = []

    // MARK: - Value Creation

    /// Starts the async operation and returns initial loading state.
    ///
    /// **Lifecycle:**
    /// 1. Creates a Task to run the async operation
    /// 2. Returns .loading() immediately
    /// 3. When operation completes, updates state and notifies dependents
    /// 4. If canceled, cleans up continuations
    ///
    /// - Returns: AsyncValue representing the operation state
    public override func providerCreate() -> AsyncValue<T> {
        let task = Task { @MainActor in
            do {
                // Run the async operation
                let value = try await provider.fetch(ref: self)

                // Check if cancelled before updating
                if Task.isCancelled { return }

                // Update state to success
                let newState: AsyncValue<T> = .data(value)
                let oldState = self.stateBox?.value
                self.stateBox?.value = newState

                // Resolve all waiting continuations
                let conts = self.continuations
                self.continuations.removeAll()
                conts.forEach { $0.resume(returning: value) }

                // Notify dependent providers
                self.notifyDependents()
                self.container.notifyProviderUpdated(provider: self.provider, oldValue: oldState ?? .loading(), newValue: newState)
            } catch {
                // Handle operation failure
                if Task.isCancelled { return }

                let actualOldState = self.stateBox?.value
                let newState: AsyncValue<T> = .error(error, previousData: actualOldState?.value)
                self.stateBox?.value = newState

                // Resolve waiting continuations with error
                let conts = self.continuations
                self.continuations.removeAll()
                conts.forEach { $0.resume(throwing: error) }

                // Notify dependents of error state
                self.notifyDependents()
                self.container.notifyProviderUpdated(provider: self.provider, oldValue: actualOldState ?? .loading(), newValue: newState)
            }
        }

        // Clean up task when provider is disposed
        onDispose {
            task.cancel()
            self.continuations.forEach { $0.resume(throwing: CancellationError()) }
            self.continuations.removeAll()
        }

        // Return initial state
        if let lastValue = stateBox?.value.value {
            return .refreshing(lastValue)
        }
        return .loading()
    }

    // MARK: - Awaitable Access

    /// Waits for the async operation to complete and returns the result.
    ///
    /// If the value is already available, returns immediately.
    /// If the value is still loading, suspends until completion.
    /// If an error occurred, throws the error.
    ///
    /// - Returns: The operation's result value
    /// - Throws: Any error from the operation
    ///
    /// **Usage:**
    /// ```swift
    /// let result = try await element.getFuture()
    /// ```
    func getFuture() async throws -> T {
        // If value is already available, return it immediately
        if let value = getState().value {
            return value
        }

        // If error occurred, throw it
        if case .error(let err, _) = getState() {
            throw err
        }

        // Otherwise wait for operation to complete
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }
}

// MARK: - FutureProvider

/// A provider that executes a one-shot async operation and caches the result.
///
/// `FutureProvider` is designed for single, fire-and-forget async operations like API calls,
/// database queries, or file I/O. It automatically manages the operation's lifecycle,
/// loading state, error handling, and result caching.
///
/// **Key Characteristics:**
/// - **One-shot**: Runs once, caches result until invalidated
/// - **Async**: Uses async/await for clean async code
/// - **Stateful**: Tracks loading → data/error progression through AsyncValue
/// - **Observable**: State changes notify dependent providers and views
/// - **Cancellable**: Automatically cancels operation when disposed
///
/// **Thread Safety:**
/// Confined to the MainActor. All operations occur on the main thread.
///
/// **State Progression:**
/// ```
/// Initial: .loading()
///      ↓
/// Success: .data(T) → Cached until invalidation
///      ↓
/// Failure: .error(Error, previousData?)
/// ```
///
/// **When to Use:**
/// - API calls to fetch data
/// - Database queries
/// - File I/O operations
/// - Any async operation that runs once and caches result
///
/// **When NOT to Use:**
/// - Continuous streams of data (use `StreamProvider`)
/// - Operations that need manual control (use `NotifierProvider`)
/// - Simple sync values (use `Provider`)
///
/// **Example: Fetch User Data**
/// ```swift
/// @FutureProvider
/// func userProvider(ref: ProviderRef) async throws -> User {
///     let url = URL(string: "https://api.example.com/user")!
///     let (data, _) = try await URLSession.shared.data(from: url)
///     return try JSONDecoder().decode(User.self, from: data)
/// }
///
/// // In a view
/// struct UserView: View {
///     @Watch(userProvider) var userState
///
///     var body: some View {
///         switch userState {
///         case .data(let user):
///             Text(user.name)
///         case .loading():
///             ProgressView()
///         case .error(let error, _):
///             Text("Error: \\(error.localizedDescription)")
///         case .refreshing(let lastUser):
///             Text(lastUser.name).opacity(0.5)
///         }
///     }
/// }
/// ```
///
/// **Example: Dependent Async Operations**
/// ```swift
/// @FutureProvider
/// func currentUserProvider(ref: ProviderRef) async throws -> User {
///     let url = URL(string: "https://api.example.com/user")!
///     let (data, _) = try await URLSession.shared.data(from: url)
///     return try JSONDecoder().decode(User.self, from: data)
/// }
///
/// @FutureProvider
/// func userPostsProvider(ref: ProviderRef) async throws -> [Post] {
///     let user = try ref.watch(currentUserProvider).unwrap()
///     let url = URL(string: "https://api.example.com/users/\\(user.id)/posts")!
///     let (data, _) = try await URLSession.shared.data(from: url)
///     return try JSONDecoder().decode([Post].self, from: data)
/// }
/// ```
///
/// **Example: Refresh with Manual Invalidation**
/// ```swift
/// @FutureProvider
/// func dataProvider(ref: ProviderRef) async throws -> Data {
///     return try await fetchData()
/// }
///
/// @Notifier
/// class RefreshNotifier extends AsyncNotifier<Void> {
///     @override
///     Future<Void> build() async {
///         ref.onAddListener(() {
///             // Refresh data when view appears
///             ref.invalidate(dataProvider)
///         })
///     }
/// }
/// ```
///
/// - Important: FutureProvider caches its result. To refresh, call `ref.invalidate()`
/// - Note: Dependencies are tracked via `ref.watch()` calls
/// - Warning: Avoid CPU-intensive operations; use task queues if needed
public struct FutureProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {

    // MARK: - Type Definition

    /// The state type is AsyncValue tracking the operation's lifecycle
    public typealias State = AsyncValue<T>

    // MARK: - Properties

    /// The async operation closure that fetches the value
    private let _create: @MainActor (ProviderRef) async throws -> T

    /// Unique identifier for this provider instance
    private let _id: AnyHashable

    /// Whether to automatically dispose when no longer listened to
    public let autoDispose: Bool

    /// Time in seconds before the cached value is invalidated
    public let cacheTime: TimeInterval

    /// Human-readable name for debugging
    public let name: String?

    // MARK: - Initialization

    /// Creates a new FutureProvider with explicit configuration.
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - cacheTime: How long to cache the result in seconds (default: 0)
    ///   - name: Optional debug name
    ///   - create: The async operation closure
    ///
    /// **Example: API Call with Timeout**
    /// ```swift
    /// let userProvider = FutureProvider(
    ///     cacheTime: 300,  // Cache for 5 minutes
    ///     name: "userProvider"
    /// ) { ref in
    ///     try await fetchUserWithTimeout()
    /// }
    /// ```
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ create: @escaping @MainActor (ProviderRef) async throws -> T
    ) {
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
        self._id = UUID()
    }

    /// Internal initializer for family providers.
    /// - Note: For internal use only.
    internal init(
        id: AnyHashable,
        autoDispose: Bool,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        create: @escaping @MainActor (ProviderRef) async throws -> T
    ) {
        self._id = id
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
    }

    // MARK: - Awaitable Access

    /// Returns a future provider that allows awaiting this provider's result.
    ///
    /// Use this to get an awaitable Task from within async code or notifier-based providers.
    ///
    /// **Example: Await in Notifier**
    /// ```swift
    /// @Notifier
    /// class DataNotifier extends AsyncNotifier<Data> {
    ///     @override
    ///     Future<Data> build() async {
    ///         return try await dataProvider.future // Await the future
    ///     }
    /// }
    /// ```
    ///
    /// **Example: Await in Provider**
    /// ```swift
    /// @Provider
    /// func processedDataProvider(ref: ProviderRef) async throws -> ProcessedData {
    ///     let data = try await ref.watch(dataProvider.future)
    ///     return process(data)
    /// }
    /// ```
    ///
    /// - Returns: A FutureFutureProvider that provides Task<T, Error>
    public var future: FutureFutureProvider<T> {
        FutureFutureProvider(provider: self)
    }

    // MARK: - Internal Methods

    /// Executes the async operation and returns the result.
    ///
    /// - Parameter ref: The provider reference for dependency tracking
    /// - Returns: The result of the async operation
    /// - Throws: Any error from the operation
    @MainActor
    func fetch(ref: ProviderRef) async throws -> T {
        try await _create(ref)
    }

    // MARK: - ProviderProtocol Conformance

    /// Creates an element to manage this provider's async operation
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        FutureProviderElement(provider: self, container: container)
    }

    /// Hashes this provider using its unique identifier
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }

    /// Two FutureProviders are equal if they have the same identifier
    public static func == (lhs: FutureProvider, rhs: FutureProvider) -> Bool {
        lhs._id == rhs._id
    }
}

// MARK: - FutureFutureProvider

/// A provider that returns an awaitable Task for a FutureProvider.
///
/// `FutureFutureProvider` is a companion provider that wraps a `FutureProvider` and
/// exposes its result as an awaitable `Task<T, Error>`. Use this when you need to
/// directly await a FutureProvider's result from within async code.
///
/// **Thread Safety:**
/// Confined to the MainActor.
///
/// **Usage Pattern:**
/// ```swift
/// // The original future provider
/// @FutureProvider
/// func dataProvider(ref: ProviderRef) async throws -> Data {
///     return try await fetchData()
/// }
///
/// // Use .future to get the awaitable version
/// let task = try await ref.watch(dataProvider.future)
/// ```
///
/// **Example: In AsyncNotifier**
/// ```swift
/// @Notifier
/// class ProcessingNotifier extends AsyncNotifier<ProcessedData> {
///     @override
///     Future<ProcessedData> build() async {
///         // Get the data via future
///         let data = try await ref.watch(dataProvider.future)
///         // Process it
///         return ProcessedData(from: data)
///     }
/// }
/// ```
///
/// - Note: This provider automatically inherits the autoDispose setting from the wrapped provider.
/// - Important: The task completes when the underlying FutureProvider's operation completes.
public struct FutureFutureProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {

    // MARK: - Type Definition

    /// The state type is a Task that can be awaited
    public typealias State = Task<T, Error>

    // MARK: - Properties

    /// The FutureProvider being wrapped
    public let provider: FutureProvider<T>

    /// Inherits auto-dispose setting from the wrapped provider
    public var autoDispose: Bool { provider.autoDispose }

    // MARK: - ProviderProtocol Conformance

    /// Creates an element that manages the awaitable task
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        FutureFutureElement(provider: self, container: container)
    }

    /// Hashes using the wrapped provider
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
    }

    /// Two FutureFutureProviders are equal if they wrap the same provider
    public static func == (lhs: FutureFutureProvider, rhs: FutureFutureProvider) -> Bool {
        lhs.provider == rhs.provider
    }
}

// MARK: - FutureFutureElement

/// Internal element that creates awaitable tasks for FutureProviders.
///
/// `FutureFutureElement` manages the task creation and lifecycle for FutureFutureProvider.
/// It creates a Task that suspends until the underlying FutureProvider completes.
///
/// **Thread Safety:**
/// Confined to the MainActor.
///
/// - Note: This is an internal implementation detail.
@MainActor
final class FutureFutureElement<T: Sendable>: ProviderElement<FutureFutureProvider<T>> {

    /// Creates an awaitable task for the wrapped FutureProvider.
    ///
    /// - Returns: A Task that completes when the FutureProvider's operation completes
    override func providerCreate() -> Task<T, Error> {
        // Ensure the parent FutureProvider element exists
        let parentElement = container.ensureElement(for: provider.provider) as! FutureProviderElement<T>
        _ = parentElement.getState()

        // Create a task that awaits the future
        return Task { @MainActor in
            try await parentElement.getFuture()
        }
    }
}
