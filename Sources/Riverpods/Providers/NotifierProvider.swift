import Foundation
import Observation

// MARK: - Notifier Base Class

/// A base class for managing complex stateful logic in providers.
///
/// `Notifier` is a class-based state manager that bridges the reactive provider system
/// with imperative state management. It's ideal for:
/// - Complex state logic that benefits from encapsulation
/// - State with methods and helper functions
/// - Lifecycle management (initialization, cleanup)
/// - Dependency watching and reacting to changes
///
/// **Key Features:**
/// - **Observable**: Conforms to the Observation protocol for SwiftUI integration
/// - **Reactive**: Can watch other providers via the `ref` property
/// - **Mutable**: State can be changed directly or through helper methods
/// - **Lifecycle-aware**: Receives initialization and recomputation callbacks
/// - **Thread-safe**: Confined to the MainActor
///
/// **Lifecycle:**
/// 1. Created: Notifier instance instantiated
/// 2. Setup: `_setup()` called to provide ref and callbacks
/// 3. Build: `build()` called to compute initial state
/// 4. Recompute: `build()` called again when dependencies change
/// 5. Update: State can be changed via `state` property or `update()` method
/// 6. Dispose: Provider disposed when no longer needed
///
/// **Thread Safety:**
/// Confined to the MainActor. All operations must occur on the main thread.
///
/// **Usage Pattern:**
/// ```swift
/// @Notifier
/// class CounterNotifier extends Notifier<Int> {
///     override func build() -> Int {
///         return 0  // Initial state
///     }
///
///     func increment() {
///         update { $0 + 1 }
///     }
///
///     func decrement() {
///         update { $0 - 1 }
///     }
/// }
/// ```
///
/// - Important: Always override the `build()` method to compute initial state.
/// - Note: The `ref` property is set internally and should not be modified directly.
/// - Warning: Do not access `state` before `build()` has been called.
@MainActor
@Observable
open class Notifier<State: Sendable> {

    // MARK: - Properties

    /// The provider reference for dependency tracking and lifecycle callbacks.
    ///
    /// Use this to:
    /// - Watch other providers: `ref.watch(someProvider)`
    /// - Listen to changes: `ref.listen(someProvider) { old, new in ... }`
    /// - Register cleanup: `ref.onDispose { ... }`
    /// - Control lifecycle: `ref.keepAlive()`, `ref.invalidate()`
    ///
    /// Set internally by the framework during provider setup.
    public internal(set) var ref: ProviderRef!

    /// The current state value, stored privately and updated via the `state` property
    @ObservationIgnored
    private var _state: State?

    /// The callback invoked when state changes, triggering dependent updates
    @ObservationIgnored
    private var onUpdate: (() -> Void)?

    // MARK: - State Management

    /// The current state value.
    ///
    /// **Getting:**
    /// - Returns the current state value
    /// - Triggers observation in SwiftUI views
    ///
    /// **Setting:**
    /// - Updates the state value
    /// - Automatically notifies all dependent providers
    /// - Triggers view refreshes if observing
    ///
    /// **Example:**
    /// ```swift
    /// notifier.state = newValue  // Direct replacement
    ///
    /// notifier.update { $0 + 1 } // Functional update
    /// ```
    public var state: State {
        get { _state! }
        set {
            _state = newValue
            onUpdate?()
        }
    }

    // MARK: - Initialization

    /// Initializes a new Notifier instance.
    ///
    /// Override this to perform custom initialization if needed.
    /// However, most initialization should be done in `build()` instead,
    /// which allows access to the provider reference and dependencies.
    public init() {}

    // MARK: - State Computation

    /// Computes the initial state value.
    ///
    /// Called:
    /// - When the notifier is first created
    /// - When a watched dependency changes (to recompute the state)
    /// - When explicitly requested via recomputation
    ///
    /// Override this to compute the initial state. This is where you:
    /// - Initialize the state based on dependencies
    /// - Set up listeners via `ref.listen()`
    /// - Register cleanup callbacks via `ref.onDispose()`
    /// - Watch other providers via `ref.watch()`
    ///
    /// **Example: With Dependencies**
    /// ```swift
    /// @Notifier
    /// class UserNotifier extends Notifier<User?> {
    ///     override func build() -> User? {
    ///         let userId = ref.watch(userIdProvider)  // Track dependency
    ///         return ref.watch(userProvider(userId))  // Another dependency
    ///     }
    /// }
    /// ```
    ///
    /// **Example: With Cleanup**
    /// ```swift
    /// override func build() -> ConnectionState {
    ///     let connection = createConnection()
    ///
    ///     ref.onDispose {
    ///         connection.close()  // Clean up on disposal
    ///     }
    ///
    ///     return connection.state
    /// }
    /// ```
    ///
    /// - Important: Must be overridden in subclasses.
    /// - Warning: Do not call directly; the framework manages this.
    open func build() -> State {
        fatalError("Must override build() method")
    }

    // MARK: - Internal Framework Methods

    /// Sets up the notifier with its provider reference and update callback.
    ///
    /// - Parameters:
    ///   - ref: The provider reference for dependency tracking
    ///   - onUpdate: Callback invoked when state changes
    ///
    /// - Note: This is called internally by the framework. Do not call directly.
    internal func _setup(ref: ProviderRef, onUpdate: @escaping () -> Void) {
        self.ref = ref
        self.onUpdate = onUpdate
    }

    /// Recomputes the state by calling `build()`.
    ///
    /// - Returns: The newly computed state
    ///
    /// - Note: This is called internally when dependencies change. Do not call directly.
    @discardableResult
    internal func _recompute() -> State {
        let newState = build()
        self._state = newState
        return newState
    }

    // MARK: - State Updates

    /// Updates the state using a transform function.
    ///
    /// This is a convenience method for functional state updates.
    /// It reads the current state, applies the transform, and sets the result.
    ///
    /// - Parameter transform: A function that takes the current state and returns a new state
    ///
    /// **Example: Increment Counter**
    /// ```swift
    /// notifier.update { $0 + 1 }
    /// ```
    ///
    /// **Example: Update Struct Property**
    /// ```swift
    /// notifier.update { state in
    ///     var updated = state
    ///     updated.name = "New Name"
    ///     updated.count += 1
    ///     return updated
    /// }
    /// ```
    ///
    /// - Note: This automatically triggers dependent provider updates.
    public func update(_ transform: (State) -> State) {
        state = transform(state)
    }
}

// MARK: - NotifierProviderElement

/// Internal element managing a NotifierProvider's notifier instance and state.
///
/// `NotifierProviderElement` is responsible for:
/// - Creating and managing the notifier instance
/// - Initializing the notifier with provider reference and callbacks
/// - Computing and caching the notifier's state
/// - Recomputing state when dependencies change
/// - Bridging state updates to the provider system
/// - Cleanup when the provider is disposed
///
/// **Lifecycle:**
/// 1. Created: Element instantiated for the provider
/// 2. Build: Notifier instance created, `build()` called to compute initial state
/// 3. Update: State can be changed via notifier.state or update()
/// 4. Dependencies: When watched providers change, `build()` called again
/// 5. Disposed: Notifier released, cleanup functions called
///
/// **Thread Safety:**
/// Confined to the MainActor. All operations occur on the main thread.
///
/// - Note: This is an internal implementation detail. Use NotifierProvider macro to create notifier-based providers.
@MainActor
public final class NotifierProviderElement<N: Notifier<T>, T: Sendable>: ProviderElement<NotifierProvider<N, T>> {

    // MARK: - Properties

    /// The notifier instance being managed
    /// Kept alive throughout the provider's lifetime
    public var notifier: N?

    // MARK: - Value Creation

    /// Creates or recomputes the notifier's state.
    ///
    /// **First call:**
    /// - Creates a new notifier instance
    /// - Sets up the notifier with provider reference
    /// - Calls `build()` to compute initial state
    ///
    /// **Subsequent calls:**
    /// - Recomputes state by calling `build()` again
    /// - Useful when watched dependencies change
    ///
    /// - Returns: The notifier's current state
    public override func providerCreate() -> T {
        if let n = notifier {
            // Dependencies changed, recompute the state
            return n._recompute()
        }

        // Initial setup - create the notifier instance
        let n = provider.createNotifier()
        notifier = n

        // Set up the notifier with provider reference and update callback
        n._setup(ref: self) { [weak self] in
            // Called when notifier.state is updated
            if let self, let newState = self.notifier?.state {
                self.stateBox?.value = newState
                self.notifyDependents()
            }
        }

        // Compute and return initial state
        return n._recompute()
    }

    /// Disposes the notifier and cleans up resources
    public override func dispose() {
        super.dispose()
        notifier = nil
    }
}

// MARK: - NotifierInstanceElement

/// Internal element providing access to the notifier instance itself.
///
/// `NotifierInstanceElement` creates a "view" of the notifier instance
/// (rather than just its state). This allows watching the notifier directly
/// to get both its state and callable methods.
///
/// **Thread Safety:**
/// Confined to the MainActor.
///
/// - Note: This is an internal implementation detail. Use .notifier to access the instance.
@MainActor
public final class NotifierInstanceElement<N: Notifier<T>, T: Sendable>: ProviderElement<NotifierInstanceProvider<N, T>> {

    /// Creates and returns the notifier instance.
    ///
    /// Ensures the parent NotifierProvider element exists and returns its notifier instance.
    ///
    /// - Returns: The notifier instance
    public override func providerCreate() -> N {
        let parentElement = container.ensureElement(for: provider.provider) as! NotifierProviderElement<N, T>
        // Ensure the notifier and its state exist
        _ = parentElement.getState()
        return parentElement.notifier!
    }
}

// MARK: - NotifierProvider

/// A provider that manages complex stateful logic using a Notifier instance.
///
/// `NotifierProvider` wraps a `Notifier` class and exposes its computed state as a provider.
/// Use NotifierProvider when you need:
/// - Complex state with methods and logic
/// - Class-based state management
/// - Encapsulation of related state and behavior
/// - Lifecycle management (initialization, cleanup)
/// - Dependency tracking and reactive updates
///
/// **Key Characteristics:**
/// - **Class-based**: State managed by a mutable Notifier instance
/// - **Observable**: The notifier conforms to Observation for SwiftUI
/// - **Reactive**: Automatically invalidates dependents when state changes
/// - **Encapsulated**: Logic and state grouped together in the notifier
/// - **Flexible**: Can combine imperative updates with reactive dependencies
///
/// **Thread Safety:**
/// Confined to the MainActor. All operations occur on the main thread.
///
/// **When to Use:**
/// - Complex state logic (use cases, workflows)
/// - State that benefits from encapsulation
/// - State with helper methods and functions
/// - Lifecycle management with cleanup
/// - Mixing imperative and reactive patterns
///
/// **When NOT to Use:**
/// - Simple state values (use `StateProvider`)
/// - Simple computed values (use `Provider`)
/// - One-shot async operations (use `FutureProvider`)
/// - Continuous streams (use `StreamProvider`)
///
/// **Example: Counter with Min/Max**
/// ```swift
/// @Notifier
/// class BoundedCounterNotifier extends Notifier<Int> {
///     let minValue = 0
///     let maxValue = 100
///
///     override func build() -> Int {
///         return 0
///     }
///
///     func increment() {
///         update { min($0 + 1, maxValue) }
///     }
///
///     func decrement() {
///         update { max($0 - 1, minValue) }
///     }
/// }
///
/// let counterProvider = NotifierProvider { BoundedCounterNotifier() }
/// ```
///
/// **Example: Form Notifier with Validation**
/// ```swift
/// @Notifier
/// class FormNotifier extends Notifier<FormState> {
///     override func build() -> FormState {
///         return FormState()
///     }
///
///     func setEmail(_ email: String) {
///         update { $0.withEmail(email) }
///     }
///
///     func submit() async throws {
///         if !validate() { throw ValidationError() }
///         let result = try await api.submit(state)
///         update { $0.withResult(result) }
///     }
///
///     private func validate() -> Bool {
///         // Form validation logic
///     }
/// }
/// ```
///
/// **Example: With Dependencies**
/// ```swift
/// @Notifier
/// class UserNotifier extends Notifier<User?> {
///     override func build() -> User? {
///         let userId = ref.watch(selectedUserIdProvider)
///         return ref.watch(userProvider(userId))
///     }
///
///     func updateName(_ name: String) {
///         update { user in
///             var updated = user
///             updated?.name = name
///             return updated
///         }
///     }
/// }
/// ```
///
/// - Important: The notifier instance persists across view rebuilds in the same provider scope.
/// - Note: State changes via notifier.state automatically notify dependent providers.
/// - Warning: Do not create multiple notifiers with the same logic; reuse the provider.
public struct NotifierProvider<N: Notifier<T>, T: Sendable>: ProviderProtocol, @unchecked Sendable {

    // MARK: - Type Definition

    /// The state type is the notifier's state generic parameter
    public typealias State = T

    // MARK: - Properties

    /// The closure that creates the notifier instance
    private let _create: @MainActor () -> N

    /// Unique identifier for this provider instance
    private let _id: AnyHashable

    /// Whether to automatically dispose when no longer listened to
    public let autoDispose: Bool

    /// Time in seconds before the state value is invalidated
    public let cacheTime: TimeInterval

    /// Human-readable name for debugging
    public let name: String?

    // MARK: - Initialization

    /// Creates a new NotifierProvider with explicit configuration.
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - cacheTime: How long to cache the state in seconds (default: 0)
    ///   - name: Optional debug name
    ///   - create: The closure that creates the notifier instance
    ///
    /// **Example: Simple Notifier**
    /// ```swift
    /// let counterProvider = NotifierProvider {
    ///     CounterNotifier()
    /// }
    /// ```
    ///
    /// **Example: With Configuration**
    /// ```swift
    /// let formProvider = NotifierProvider(
    ///     autoDispose: false,  // Keep form state alive
    ///     name: "formProvider"
    /// ) {
    ///     FormNotifier()
    /// }
    /// ```
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ create: @escaping @MainActor () -> N
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
        create: @escaping @MainActor () -> N
    ) {
        self._id = id
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
    }

    // MARK: - Internal Methods

    /// Creates a new notifier instance
    @MainActor
    func createNotifier() -> N {
        _create()
    }

    // MARK: - ProviderProtocol Conformance

    /// Creates an element to manage the notifier instance
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        NotifierProviderElement(provider: self, container: container)
    }

    /// Hashes this provider using its unique identifier
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }

    /// Two NotifierProviders are equal if they have the same identifier
    public static func == (lhs: NotifierProvider, rhs: NotifierProvider) -> Bool {
        lhs._id == rhs._id
    }

    // MARK: - Instance Access

    /// Returns a provider that gives access to the notifier instance itself.
    ///
    /// Use this when you need to call methods on the notifier or access it directly.
    ///
    /// **Example: Access Notifier Instance**
    /// ```swift
    /// @Watch(counterProvider.notifier) var counter
    ///
    /// // Call notifier methods
    /// counter.increment()
    /// counter.decrement()
    ///
    /// // Access state
    /// let currentCount = counter.state
    /// ```
    ///
    /// - Returns: A NotifierInstanceProvider for accessing the notifier instance
    public var notifier: NotifierInstanceProvider<N, T> {
        NotifierInstanceProvider(provider: self)
    }
}

// MARK: - NotifierInstanceProvider

/// A provider that returns the notifier instance rather than just its state.
///
/// `NotifierInstanceProvider` is a companion provider accessible via `.notifier`
/// on any NotifierProvider. It allows watching the notifier instance directly,
/// giving you access to both its state and callable methods.
///
/// **Thread Safety:**
/// Confined to the MainActor.
///
/// **Usage Pattern:**
/// ```swift
/// // Watch the state value
/// @Watch(counterProvider) var count
///
/// // Or watch the notifier instance
/// @Watch(counterProvider.notifier) var counter
/// counter.increment()
/// counter.state  // Access state from the instance
/// ```
///
/// **Example: Both Views of the Same Data**
/// ```swift
/// // View A: Just wants the count value
/// struct CountDisplay: View {
///     @Watch(counterProvider) var count
///     var body: some View { Text("\\(count)") }
/// }
///
/// // View B: Wants to call methods on the notifier
/// struct CountControls: View {
///     @Watch(counterProvider.notifier) var counter
///     var body: some View {
///         Button("Increment") { counter.increment() }
///         Button("Decrement") { counter.decrement() }
///     }
/// }
/// ```
///
/// - Note: This provider automatically inherits the autoDispose setting from the wrapped provider.
/// - Important: The notifier instance persists; only the state updates trigger view refreshes.
public struct NotifierInstanceProvider<N: Notifier<T>, T: Sendable>: ProviderProtocol, @unchecked Sendable {

    // MARK: - Type Definition

    /// The state type is the notifier instance itself
    public typealias State = N

    // MARK: - Properties

    /// The NotifierProvider whose notifier instance this provider returns
    let provider: NotifierProvider<N, T>

    /// Inherits auto-dispose setting from the wrapped provider
    public var autoDispose: Bool { provider.autoDispose }

    // MARK: - ProviderProtocol Conformance

    /// Creates an element that provides access to the notifier instance
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        NotifierInstanceElement(provider: self, container: container)
    }

    /// Hashes using the wrapped provider and "instance" suffix
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
        hasher.combine("instance")
    }

    /// Two NotifierInstanceProviders are equal if they wrap the same provider
    public static func == (lhs: NotifierInstanceProvider, rhs: NotifierInstanceProvider) -> Bool {
        lhs.provider == rhs.provider
    }
}
