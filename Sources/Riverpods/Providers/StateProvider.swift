import Foundation
import Observation

// MARK: - StateProviderElement

/// Internal element managing a StateProvider's mutable state.
///
/// `StateProviderElement` is responsible for:
/// - Computing the initial state value
/// - Caching and storing the current state
/// - Notifying dependents when state changes
/// - Triggering invalidation when updates occur
///
/// **Thread Safety:**
/// Confined to the MainActor.
///
/// - Note: This is an internal implementation detail. Use StateProvider macro to create mutable state providers.
@MainActor
public final class StateProviderElement<T: Sendable>: ProviderElement<StateProvider<T>> {

    // MARK: - Properties

    /// The current state value, lazily initialized
    private var _currentValue: T?

    // MARK: - Value Creation

    /// Creates the initial state value on first access.
    ///
    /// Called when the provider is first accessed. Subsequent calls return the
    /// cached value until explicitly updated.
    ///
    /// - Returns: The initial state value
    public override func providerCreate() -> T {
        if let value = _currentValue {
            return value
        }
        let initial = provider.defaultValue(ref: self)
        _currentValue = initial
        return initial
    }

    // MARK: - State Mutation

    /// Updates the state value and notifies dependents.
    ///
    /// Called when the state is explicitly changed (e.g., through a StateController).
    /// Triggers invalidation and notifies all dependent providers.
    ///
    /// - Parameter newValue: The new state value
    ///
    /// **Side Effects:**
    /// - Updates the cached state
    /// - Marks this element for update
    /// - Notifies all dependent providers
    func updateState(_ newValue: T) {
        _currentValue = newValue
        invalidate()
    }
}

// MARK: - StateProvider

/// A provider that stores and manages mutable state that can be updated directly.
///
/// `StateProvider<T>` is the reactive foundation for mutable state in the Riverpods system.
/// Unlike `Provider` which is read-only and recomputed based on dependencies, StateProvider
/// allows direct mutation through a `StateController` accessible via the `notifier` property.
///
/// **Key Characteristics:**
/// - **Mutable**: State can be updated imperatively via StateController
/// - **Observed**: Changes automatically notify all dependent providers
/// - **Cached**: Updates are memoized; dependents only notify if value actually changed
/// - **Reactive**: Dependents automatically invalidate on state changes
///
/// **Thread Safety:**
/// Confined to the MainActor. All updates must occur on the main thread.
///
/// **Lifecycle:**
/// 1. Created: Provider registered with initial value
/// 2. First Access: Default value computed from closure
/// 3. Mutation: Updated through StateController.state setter
/// 4. Dependent Updates: All dependent providers automatically invalidated
/// 5. Disposal: Cleaned up when no longer needed (if autoDispose is true)
///
/// **When to Use:**
/// - Simple mutable application state (current user, UI flags, search query)
/// - Local component state (form values, expanded/collapsed states)
/// - User input tracking
/// - Animation states
/// - Any state that's primarily updated imperatively, not computed
///
/// **When NOT to Use:**
/// - Computed values (use `Provider` instead)
/// - Values derived from other state (use `Provider` instead)
/// - Complex async operations (use `FutureProvider` or `StreamProvider`)
/// - Values that require side effects (use `NotifierProvider`)
///
/// **Example: Simple Counter State**
/// ```swift
/// @StateProvider
/// func counterProvider() -> Int {
///     return 0  // Initial value
/// }
///
/// // In a view
/// struct CounterView: View {
///     @Watch(counterProvider) var count
///     @Watch(counterProvider.notifier) var controller
///
///     var body: some View {
///         VStack {
///             Text("Count: \\(count)")
///
///             Button("Increment") {
///                 controller.state += 1  // Direct mutation
///             }
///         }
///     }
/// }
/// ```
///
/// **Example: Form State**
/// ```swift
/// @StateProvider
/// func userFormProvider(ref: ProviderRef) -> UserFormState {
///     return UserFormState()
/// }
///
/// @Provider
/// func isFormValidProvider(ref: ProviderRef) -> Bool {
///     let form = ref.watch(userFormProvider)
///     return !form.email.isEmpty && !form.password.isEmpty
/// }
///
/// // Update form
/// @Watch(userFormProvider.notifier) var formController
/// formController.state.email = "user@example.com"
/// ```
///
/// **Example: Composition with Other Providers**
/// ```swift
/// @StateProvider
/// func selectedUserIdProvider() -> Int? {
///     return nil
/// }
///
/// @Provider
/// func selectedUserProvider(ref: ProviderRef) -> User? {
///     guard let userId = ref.watch(selectedUserIdProvider) else { return nil }
///     return ref.watch(userProvider(userId))
/// }
///
/// // Select a user
/// @Watch(selectedUserIdProvider.notifier) var idController
/// idController.state = 42  // Triggers selectedUserProvider to recompute
/// ```
///
/// - Important: Do not attempt to derive computed values from StateProvider. Use Provider for that.
/// - Note: Default value closure can access other providers via ref.watch()
/// - Warning: Avoid storing references to StateController across boundaries; access through notifier each time.
public struct StateProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {

    // MARK: - Type Definition

    /// The mutable state type managed by this provider
    public typealias State = T

    // MARK: - Properties

    /// The closure that computes the initial state value
    private let _defaultValue: @MainActor (ProviderRef) -> T

    /// Unique identifier for this provider instance
    private let _id: AnyHashable

    /// Whether to automatically dispose when no longer listened to
    public let autoDispose: Bool

    /// Time in seconds before the state value is invalidated
    public let cacheTime: TimeInterval

    /// Human-readable name for debugging
    public let name: String?

    // MARK: - Initialization

    /// Creates a new StateProvider with explicit configuration.
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - cacheTime: How long to cache the value in seconds (default: 0, no time-based expiration)
    ///   - name: Optional debug name
    ///   - defaultValue: Closure computing the initial state value
    ///
    /// **Example: Simple Counter**
    /// ```swift
    /// let counterProvider = StateProvider(
    ///     autoDispose: true,
    ///     name: "counterProvider"
    /// ) { ref in
    ///     return 0
    /// }
    /// ```
    ///
    /// **Example: State with Dependencies**
    /// ```swift
    /// let userFormProvider = StateProvider(
    ///     name: "userFormProvider"
    /// ) { ref in
    ///     let user = ref.watch(currentUserProvider)
    ///     return UserFormState(from: user)
    /// }
    /// ```
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ defaultValue: @escaping @MainActor (ProviderRef) -> T
    ) {
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._defaultValue = defaultValue
        self._id = UUID()
    }

    /// Internal initializer for family providers.
    /// - Note: For internal use only.
    internal init(
        id: AnyHashable,
        autoDispose: Bool,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        defaultValue: @escaping @MainActor (ProviderRef) -> T
    ) {
        self._id = id
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._defaultValue = defaultValue
    }

    // MARK: - ProviderProtocol Conformance

    /// Creates an element to manage this provider's state
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        StateProviderElement(provider: self, container: container)
    }

    /// Computes the initial state value via the default value closure
    @MainActor
    func defaultValue(ref: ProviderRef) -> T {
        _defaultValue(ref)
    }

    /// Hashes this provider using its unique identifier
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }

    /// Two StateProviders are equal if they have the same identifier
    public static func == (lhs: StateProvider, rhs: StateProvider) -> Bool {
        lhs._id == rhs._id
    }

    // MARK: - State Control

    /// Returns the notifier that provides access to mutate this state provider's value.
    ///
    /// Access this to get a `StateController` that allows reading and writing the state.
    /// The notifier is itself a provider, so it can be watched like any other provider.
    ///
    /// **Example: Accessing StateController**
    /// ```swift
    /// @Watch(counterProvider.notifier) var controller
    ///
    /// // Read current state
    /// let currentCount = controller.state
    ///
    /// // Update state
    /// controller.state += 1
    /// ```
    ///
    /// - Returns: A StateProviderNotifier that provides state mutation
    public var notifier: StateProviderNotifier<T> {
        StateProviderNotifier(provider: self)
    }
}

// MARK: - StateProviderNotifier

/// A provider that grants access to a StateProvider's state for mutation.
///
/// `StateProviderNotifier` is a companion provider that wraps a `StateProvider` and
/// returns a `StateController` capable of reading and mutating the state.
///
/// **Purpose:**
/// While `StateProvider` holds the state value, `StateProviderNotifier` provides
/// the interface to mutate it. This separation allows:
/// - Reading state directly from StateProvider
/// - Mutating state through StateProviderNotifier.state setter
/// - Keeping direct state reads cheap (no controller overhead)
/// - Enabling fine-grained reactivity
///
/// **Thread Safety:**
/// Confined to the MainActor.
///
/// **Usage Pattern:**
/// ```swift
/// // Watch the state value directly
/// @Watch(stateProvider) var currentValue
///
/// // Watch the controller for mutations
/// @Watch(stateProvider.notifier) var controller
///
/// // Update through controller
/// controller.state = newValue  // Direct mutation
/// ```
///
/// **Example: Reading vs. Mutating**
/// ```swift
/// @StateProvider
/// func counterProvider() -> Int {
///     return 0
/// }
///
/// // In view A: Just read the count
/// @Watch(counterProvider) var count  // Direct value
///
/// // In view B: Mutate the count
/// @Watch(counterProvider.notifier) var controller
/// Button("Increment") {
///     controller.state += 1
/// }
/// ```
///
/// - Note: Accessing the notifier creates a dependency on state changes via StateController
/// - Important: The notifier is itself a provider and can be watched like any other
public struct StateProviderNotifier<T: Sendable>: ProviderProtocol, @unchecked Sendable {

    // MARK: - Type Definition

    /// The state type is a StateController for mutation
    public typealias State = StateController<T>

    // MARK: - Properties

    /// The StateProvider being managed
    let provider: StateProvider<T>

    /// Inherits auto-dispose setting from the wrapped provider
    public var autoDispose: Bool { provider.autoDispose }

    // MARK: - ProviderProtocol Conformance

    /// Creates an element that provides access to the StateController
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        SimpleProviderElement(provider: self, container: container) { ref in
            // Get the state provider's element
            let element = container.ensureElement(for: provider) as! StateProviderElement<T>
            let initialState = element.getState()

            // Return a controller that can mutate the state
            return StateController(initialState) { newValue in
                element.updateState(newValue)
            }
        }
    }

    /// Hashes the notifier using its provider and a "notifier" suffix
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
        hasher.combine("notifier")
    }

    /// Two notifiers are equal if they wrap the same provider
    public static func == (lhs: StateProviderNotifier, rhs: StateProviderNotifier) -> Bool {
        lhs.provider == rhs.provider
    }
}

// MARK: - StateController

/// An observable controller for reading and mutating StateProvider values.
///
/// `StateController` is the interface to a mutable state provider's value. It wraps
/// the current state and provides a `state` property for reading and writing.
///
/// **Thread Safety:**
/// Confined to the MainActor and fully observable via the Observable protocol.
/// Updates are automatically observed and propagate to SwiftUI views.
///
/// **Usage Pattern:**
/// ```swift
/// @Watch(counterProvider.notifier) var controller
///
/// // Read the current state
/// let currentCount = controller.state
///
/// // Update the state (triggers dependent invalidation)
/// controller.state = newValue
/// ```
///
/// **Observable:**
/// Conforms to the Observation protocol, enabling SwiftUI integration.
/// Modifications to the `state` property automatically trigger view updates.
///
/// **Example: Form Control**
/// ```swift
/// @StateProvider
/// func formProvider() -> FormData {
///     return FormData()
/// }
///
/// struct FormView: View {
///     @Watch(formProvider.notifier) var form
///
///     var body: some View {
///         TextField("Name", text: Binding(
///             get: { form.state.name },
///             set: { form.state.name = $0 }
///         ))
///
///         TextField("Email", text: Binding(
///             get: { form.state.email },
///             set: { form.state.email = $0 }
///         ))
///     }
/// }
/// ```
///
/// **Example: Complex State Update**
/// ```swift
/// @StateProvider
/// func appStateProvider() -> AppState {
///     return AppState()
/// }
///
/// @Watch(appStateProvider.notifier) var appState
///
/// // Update with computed values
/// let newState = appState.state
/// newState.count += 1
/// newState.lastUpdate = Date()
/// appState.state = newState  // Single update triggers all dependents
/// ```
///
/// - Important: The state property setter automatically notifies all dependent providers.
/// - Note: StateController is created by StateProviderNotifier on demand.
/// - See Also: StateProvider, StateProviderNotifier
@MainActor
public final class StateController<T: Sendable>: Observable {

    // MARK: - Properties

    /// The current state value.
    ///
    /// Reading returns the current state value. Writing updates the state and
    /// automatically notifies all dependent providers.
    ///
    /// **Getter:**
    /// - Returns: The current mutable state
    ///
    /// **Setter:**
    /// - Updates the state value
    /// - Triggers invalidation of this provider
    /// - Notifies all dependent providers to recompute
    /// - Observes through the Observable protocol for SwiftUI integration
    ///
    /// **Example: Simple Mutation**
    /// ```swift
    /// controller.state = newValue  // Direct replacement
    ///
    /// // Or mutating update
    /// controller.state.count += 1
    /// controller.state.name = "Updated"
    /// ```
    public var state: T {
        get { _state }
        set {
            _state = newValue
            onUpdate(newValue)
        }
    }

    // MARK: - Properties (Private)

    /// The internal mutable state storage
    private var _state: T

    /// Callback triggered when state changes
    ///
    /// Called on every state update to notify the element and dependent providers.
    private let onUpdate: (T) -> Void

    // MARK: - Initialization

    /// Initializes a StateController with initial state and update callback.
    ///
    /// - Parameters:
    ///   - initialState: The initial state value
    ///   - onUpdate: Callback invoked when state is updated
    ///
    /// - Note: This is created internally by StateProviderNotifier
    init(_ initialState: T, onUpdate: @escaping (T) -> Void) {
        self._state = initialState
        self.onUpdate = onUpdate
    }
}
