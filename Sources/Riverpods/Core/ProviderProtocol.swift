import Foundation

// MARK: - ProviderProtocol

/// The base protocol that all providers must conform to.
///
/// `ProviderProtocol` defines the fundamental contract for all provider types in the framework.
/// Every provider, regardless of its specific implementation (synchronous, asynchronous, reactive, etc.),
/// must conform to this protocol to be recognized and managed by the provider container.
///
/// **Key Responsibilities:**
/// - Define the state type that the provider produces
/// - Specify lifecycle configuration (autoDispose, cacheTime)
/// - Create provider elements for state management
/// - Support hashing and equality for identification
///
/// **Lifecycle Configuration:**
/// - `autoDispose`: Whether to automatically remove from memory when unused
/// - `cacheTime`: How long to keep cached values (0 = cache until dependencies change)
/// - `name`: Human-readable name for debugging
///
/// **Example: Custom Provider Implementation**
/// ```swift
/// struct MyCustomProvider: ProviderProtocol {
///     typealias State = String
///     var autoDispose: Bool { true }
///     var cacheTime: TimeInterval { 60 }  // Cache for 1 minute
///     var name: String? { "myCustomProvider" }
///
///     @MainActor
///     func createElement(container: ProviderContainer) -> AnyProviderElement {
///         // Create and return the element managing this provider
///         MyProviderElement(provider: self, container: container)
///     }
/// }
/// ```
///
/// **Conforming to ProviderProtocol:**
/// When creating a custom provider:
/// 1. Define the `State` associated type
/// 2. Optionally override `autoDispose`, `cacheTime`, `name`
/// 3. Implement `createElement(container:)` to create the managing element
/// 4. Ensure all types are `Sendable` and `Hashable`
///
/// - Important: All providers must be `Sendable` and `Hashable` for proper caching and equality checks.
/// - Note: The framework automatically manages lifecycle based on configuration.
public protocol ProviderProtocol: Hashable, Sendable {

    // MARK: - Associated Types

    /// The type of value this provider produces.
    /// Can be any Sendable type: simple values, structs, async results, etc.
    associatedtype State

    // MARK: - Lifecycle Configuration

    /// Whether this provider should be automatically disposed when no longer used.
    ///
    /// When `true` (default), the provider is removed from memory when:
    /// - All listeners stop watching the provider
    /// - The cache time (if set) has expired
    /// - The container is explicitly cleared
    ///
    /// When `false`, the provider persists in memory for the app lifetime,
    /// even if no one is watching it.
    ///
    /// **Use `false` when:**
    /// - Provider is expensive to recreate
    /// - You need guaranteed instant access
    /// - It's a critical singleton-like resource
    ///
    /// **Default:** `true`
    var autoDispose: Bool { get }

    /// Time in seconds before the cached value is invalidated.
    ///
    /// - `0` (default): Keep cached value until dependencies change
    /// - `> 0`: Re-compute after this many seconds, even if dependencies haven't changed
    ///
    /// **Example: 60 second cache**
    /// ```swift
    /// var cacheTime: TimeInterval { 60 }
    /// // Value recomputed after 60 seconds of no activity
    /// ```
    ///
    /// **Use for:**
    /// - API responses that should refresh periodically
    /// - Data that becomes stale over time
    /// - Polling scenarios where you want regular updates
    ///
    /// **Default:** `0` (cache until dependencies change)
    var cacheTime: TimeInterval { get }

    /// Human-readable name for this provider.
    ///
    /// Used for debugging, logging, and introspection. Helpful for:
    /// - Understanding provider state in dev tools
    /// - Filtering logs by provider
    /// - Diagnosing provider lifecycle issues
    ///
    /// **Convention:** Use camelCase with "Provider" suffix
    /// ```swift
    /// var name: String? { "userProfileProvider" }
    /// var name: String? { "fetchDataProvider" }
    /// ```
    ///
    /// **Default:** `nil` (no name, but provider still works)
    var name: String? { get }

    // MARK: - Element Creation

    /// Creates an element to manage this provider's lifecycle and value.
    ///
    /// The framework calls this method when the provider needs to be instantiated.
    /// The returned element is responsible for computing, caching, and invalidating the provider's value.
    ///
    /// - Parameter container: The container that manages all providers
    /// - Returns: An AnyProviderElement wrapping the actual provider element
    ///
    /// **Implementation Note:**
    /// This method is called on the MainActor to ensure thread safety.
    /// The returned element must also conform to MainActor constraints.
    @MainActor
    func createElement(container: ProviderContainer) -> AnyProviderElement
}

// MARK: - ProviderProtocol Defaults

extension ProviderProtocol {

    /// Default: Auto-dispose when unused.
    public var autoDispose: Bool { true }

    /// Default: Cache until dependencies change (no time-based expiration).
    public var cacheTime: TimeInterval { 0 }

    /// Default: No debug name.
    public var name: String? { nil }

    // MARK: - Overriding

    /// Creates an override that replaces this provider's value with a fixed value.
    ///
    /// Useful for testing, stubbing, and debugging. When an override is active,
    /// the provider always returns the overridden value instead of computing normally.
    ///
    /// - Parameter value: The value to use instead of the normal computed value
    /// - Returns: A ProviderOverride that can be used with `ProviderScope.overrides`
    ///
    /// **Example: Testing**
    /// ```swift
    /// let override = userProvider.overrideWith(User(name: "Test User"))
    ///
    /// ProviderScope(overrides: [override]) {
    ///     UserProfileView()
    /// }
    /// ```
    ///
    /// **Example: Debugging**
    /// ```swift
    /// let errorOverride = dataProvider.overrideWith(sampleErrorData)
    /// // View now shows error state with real error UI
    /// ```
    public func overrideWith(_ value: State) -> ProviderOverride {
        ProviderOverride(providerID: ProviderID(self), value: value, providerOverride: nil)
    }

    /// Creates an override that replaces this provider with another provider.
    ///
    /// Allows substituting the entire provider implementation. The replacement provider
    /// must have the same State type.
    ///
    /// - Parameter provider: The provider to use instead of this one
    /// - Returns: A ProviderOverride for use in ProviderScope
    ///
    /// **Example: Swap Implementations**
    /// ```swift
    /// let override = dataProvider.overrideWithProvider(mockDataProvider)
    /// // Now uses mockDataProvider instead of real dataProvider
    /// ```
    ///
    /// **Use cases:**
    /// - Swap real API for mock API in tests
    /// - Switch between implementations at runtime
    /// - A/B testing different strategies
    public func overrideWithProvider<P: ProviderProtocol>(_ provider: P) -> ProviderOverride where P.State == State {
        ProviderOverride(providerID: ProviderID(self), value: nil, providerOverride: provider)
    }

    // MARK: - Selection

    /// Creates a selector that only watches a specific part of this provider's state.
    ///
    /// Selectors are optimized for performance: views only rebuild when the selected value changes,
    /// not when other parts of the state change. This prevents unnecessary UI updates.
    ///
    /// - Parameter keyPath: KeyPath pointing to the value you want to select
    /// - Returns: A SelectorProvider that watches only the selected value
    ///
    /// **Example: Select Single Field**
    /// ```swift
    /// @Watch(userProvider.select(\.name)) var userName
    /// // Rebuilds only when name changes, not when age or email changes
    /// ```
    ///
    /// **Example: Select Nested Value**
    /// ```swift
    /// @Watch(userProvider.select(\.profile.avatarURL)) var avatarURL
    /// // Watches only the nested avatarURL field
    /// ```
    ///
    /// **Example: Select Computed Field**
    /// ```swift
    /// @Watch(userProvider.select(\.isAdmin)) var isAdmin
    /// // isAdmin is computed from the State, only watched when it changes
    /// ```
    ///
    /// **Performance Benefit:**
    /// ```swift
    /// // Without selector: rebuilds whenever userProvider changes
    /// @Watch(userProvider) var user
    ///
    /// // With selector: rebuilds only when the selected value changes
    /// @Watch(userProvider.select(\.email)) var email
    /// ```
    ///
    /// **Generic Constraint:** Selected type must be `Sendable` and `Hashable` for proper equality checking.
    public func select<Selected: Sendable & Hashable>(
        _ keyPath: KeyPath<State, Selected>
    ) -> SelectorProvider<Self, Selected> {
        SelectorProvider(provider: self, keyPath: keyPath)
    }
}

// MARK: - ProviderOverride

/// A record that overrides a provider's value or implementation.
///
/// `ProviderOverride` is used to temporarily replace a provider's behavior for testing,
/// debugging, or A/B testing. It can either override the value directly or replace the
/// entire provider implementation.
///
/// **Usage in ProviderScope:**
/// ```swift
/// ProviderScope(overrides: [override1, override2]) {
///     ContentView()
/// }
/// ```
///
/// **Types of Overrides:**
/// 1. Value override: Replace computed value with a fixed value
/// 2. Provider override: Replace entire provider with another
///
/// - Note: Only one override per provider can be active at a time.
public struct ProviderOverride: @unchecked Sendable {

    // MARK: - Properties

    /// The provider being overridden
    let providerID: ProviderID

    /// The value to use (for value overrides)
    let value: Any?

    /// The replacement provider (for provider overrides)
    let providerOverride: (any ProviderProtocol)?
}

// MARK: - SelectorProvider

/// A provider that selects a specific part of another provider's state.
///
/// `SelectorProvider` wraps another provider and extracts a value using a KeyPath.
/// This enables fine-grained reactivity: views rebuild only when the selected value changes,
/// not when other parts of the parent provider's state change.
///
/// **Internal Use:**
/// SelectorProvider is created internally by calling `.select()` on any provider.
/// You don't typically create these directly.
///
/// **Example: Created by select()**
/// ```swift
/// let userProvider: Provider<User> = ...
/// let nameSelector = userProvider.select(\.name)
/// // nameSelector is a SelectorProvider<Provider<User>, String>
/// ```
///
/// **Performance Characteristics:**
/// - Watches the parent provider's full state
/// - Only notifies dependents when selected value changes
/// - Prevents unnecessary UI rebuilds
///
/// **Thread Safety:**
/// Confined to the MainActor via the element implementation.
public struct SelectorProvider<P: ProviderProtocol, Selected: Sendable & Hashable>: ProviderProtocol, @unchecked Sendable {

    // MARK: - Type Definition

    /// The selected value type extracted from the parent provider
    public typealias State = Selected

    // MARK: - Properties

    /// The parent provider being selected from
    public let provider: P

    /// The KeyPath that extracts the selected value from the parent's state
    public let keyPath: KeyPath<P.State, Selected>

    // MARK: - ProviderProtocol Conformance

    /// Inherits auto-dispose setting from parent provider
    public var autoDispose: Bool { provider.autoDispose }

    // MARK: - Initialization

    /// Creates a selector for a specific part of a provider's state.
    ///
    /// - Parameters:
    ///   - provider: The parent provider to select from
    ///   - keyPath: The KeyPath pointing to the value to select
    public init(provider: P, keyPath: KeyPath<P.State, Selected>) {
        self.provider = provider
        self.keyPath = keyPath
    }

    // MARK: - Element Creation

    /// Creates an element that manages the selector's state and caching.
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        SelectorProviderElement(provider: self, container: container)
    }

    // MARK: - Hashable Conformance

    /// Hashes both the parent provider and the key path
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
        hasher.combine(keyPath)
    }

    /// Two selectors are equal if they wrap the same provider and key path
    public static func == (lhs: SelectorProvider, rhs: SelectorProvider) -> Bool {
        lhs.provider == rhs.provider && lhs.keyPath == rhs.keyPath
    }
}

// MARK: - SelectorProviderElement

/// Internal element that manages a selector's lifecycle and value caching.
///
/// `SelectorProviderElement` is responsible for:
/// - Watching the parent provider
/// - Extracting the selected value via KeyPath
/// - Tracking the last selected value
/// - Only notifying when the selected value changes
///
/// **Design:**
/// This element optimizes reactivity by preventing updates when non-selected parts
/// of the parent state change. It maintains `_lastValue` to detect actual changes
/// in the selected field.
///
/// - Note: This is an internal implementation detail. Selectors are created via `.select()`.
@MainActor
public final class SelectorProviderElement<P: ProviderProtocol, Selected: Sendable & Hashable>: ProviderElement<SelectorProvider<P, Selected>> {

    // MARK: - Properties

    /// The last selected value, used to detect changes
    /// When the newly selected value differs from this, dependents are notified
    private var _lastValue: Selected?

    // MARK: - Value Creation

    /// Computes the selected value on first access.
    ///
    /// Watches the parent provider (creating a dependency) and extracts
    /// the selected value via KeyPath.
    ///
    /// - Returns: The selected value extracted from the parent's state
    public override func providerCreate() -> Selected {
        let state = watch(provider.provider)
        let newValue = state[keyPath: provider.keyPath]
        _lastValue = newValue
        return newValue
    }

    // MARK: - Updates

    /// Called when the parent provider updates.
    ///
    /// Checks if the selected value changed. Only notifies dependents
    /// (triggering rebuilds) if the selected value is different.
    public override func performUpdate() {
        let state = read(provider.provider)
        let newValue = state[keyPath: provider.keyPath]

        if newValue != _lastValue {
            _lastValue = newValue
            stateBox?.value = newValue
            notifyDependents()
        }
    }
}
