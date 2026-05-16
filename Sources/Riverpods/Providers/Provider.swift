import Foundation

// MARK: - SimpleProviderElement

/// An internal element implementation for synchronous providers.
///
/// `SimpleProviderElement` wraps the provider's creation logic and manages its lifecycle
/// within the provider container. It's responsible for computing and caching the provider's value.
///
/// - Note: This is an internal implementation detail. Use `Provider` macro for creating providers.
@MainActor
public final class SimpleProviderElement<P: ProviderProtocol>: ProviderElement<P> {

    // MARK: - Properties

    /// The closure that computes the provider's value.
    /// This is called when the provider needs to create or recompute its state.
    private let _create: (ProviderRef) -> P.State

    // MARK: - Initialization

    /// Initializes a SimpleProviderElement with a provider and its creation logic.
    ///
    /// - Parameters:
    ///   - provider: The provider this element represents
    ///   - container: The container managing this provider's lifecycle
    ///   - create: The closure that computes the provider's value
    public init(
        provider: P,
        container: ProviderContainer,
        create: @escaping (ProviderRef) -> P.State
    ) {
        self._create = create
        super.init(provider: provider, container: container)
    }

    // MARK: - Value Creation

    /// Computes the provider's value by invoking the creation closure.
    ///
    /// Called by the framework when the provider's value needs to be computed or recomputed.
    ///
    /// - Returns: The computed value
    public override func providerCreate() -> P.State {
        return _create(self)
    }
}

// MARK: - Provider

/// A read-only provider that computes and caches a derived value based on other providers.
///
/// `Provider` is typically used for selectors and computed values that depend on other providers.
/// It's a lightweight, synchronous provider that caches its result until dependencies change.
///
/// **Key Features:**
/// - **Synchronous**: Computes values synchronously without async/await
/// - **Lazy**: Only computes when first accessed
/// - **Cached**: Memoizes results between recomputations
/// - **Reactive**: Automatically updates when watched providers change
/// - **Read-only**: Consumers can only read, not modify the value
///
/// **Lifecycle:**
/// 1. Created: Provider registered in the container
/// 2. First Access: Creation closure invoked
/// 3. Cached: Value stored until dependencies change
/// 4. Auto-dispose: Removed from memory if unused (when `autoDispose` is true)
///
/// **Example: Basic Selector**
/// ```swift
/// @Provider
/// func userNameProvider(ref: ProviderRef) -> String {
///     let user = ref.watch(currentUserProvider)
///     return user.firstName + " " + user.lastName
/// }
///
/// // Usage in a view
/// struct UserGreeting: View {
///     @Watch(userNameProvider) var userName
///
///     var body: some View {
///         Text("Hello, \(userName)")
///     }
/// }
/// ```
///
/// **Example: Filtered Selector**
/// ```swift
/// @Provider
/// func activeUsersProvider(ref: ProviderRef) -> [User] {
///     let allUsers = ref.watch(allUsersProvider)
///     return allUsers.filter { $0.isActive }
/// }
/// ```
///
/// **Example: Complex Derived Value**
/// ```swift
/// @Provider
/// func userStatisticsProvider(ref: ProviderRef) -> UserStats {
///     let user = ref.watch(currentUserProvider)
///     let posts = ref.watch(userPostsProvider)
///     let comments = ref.watch(userCommentsProvider)
///
///     return UserStats(
///         name: user.name,
///         postCount: posts.count,
///         commentCount: comments.count,
///         engagement: Double(comments.count) / Double(posts.count)
///     )
/// }
/// ```
///
/// - Important: Provider creation closures should be pure (deterministic) and without side effects.
///   To run side effects, use HookEffect or a notifier-based provider instead.
public struct Provider<T: Sendable>: ProviderProtocol, @unchecked Sendable {

    // MARK: - Type Definition

    /// The type of value produced by this provider
    public typealias State = T

    // MARK: - Properties

    /// The closure that computes the provider's value.
    /// Must be a pure function without side effects.
    private let _create: @MainActor (ProviderRef) -> T

    /// Unique identifier for this provider instance.
    /// Used for equality and hashing.
    private let _id: AnyHashable

    /// Whether the provider should be automatically disposed when no longer listened to.
    /// When true, frees memory by removing the provider from the container when unused.
    public let autoDispose: Bool

    /// How long the value should be cached, in seconds.
    /// A value of 0 means cache until dependencies change.
    /// After this time, the value will be recomputed even if dependencies haven't changed.
    public let cacheTime: TimeInterval

    /// Optional human-readable name for debugging and logging.
    /// Useful for understanding provider state in dev tools and logs.
    public let name: String?

    // MARK: - Initialization

    /// Creates a new Provider with explicit configuration.
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - cacheTime: How long to cache the value in seconds (default: 0, meaning cache until dependencies change)
    ///   - name: Optional debug name for this provider
    ///   - create: The closure that computes the provider's value
    ///
    /// **Example:**
    /// ```swift
    /// let userNameProvider = Provider(
    ///     autoDispose: true,
    ///     cacheTime: 60, // Cache for 1 minute
    ///     name: "userNameProvider"
    /// ) { ref in
    ///     let user = ref.watch(currentUserProvider)
    ///     return user.name
    /// }
    /// ```
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ create: @escaping @MainActor (ProviderRef) -> T
    ) {
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
        self._id = UUID()
    }

    /// Internal initializer for family providers.
    /// - Note: For internal use only. Use macros instead.
    internal init(
        id: AnyHashable,
        autoDispose: Bool,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        create: @escaping @MainActor (ProviderRef) -> T
    ) {
        self._id = id
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
    }

    // MARK: - ProviderProtocol Conformance

    /// Creates an element to manage this provider's state and lifecycle.
    ///
    /// Called by the framework to instantiate the provider element when first needed.
    ///
    /// - Parameter container: The container managing this provider
    /// - Returns: An AnyProviderElement wrapping the SimpleProviderElement
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        SimpleProviderElement(provider: self, container: container, create: _create)
    }

    // MARK: - Hashable Conformance

    /// Hashes this provider using its unique identifier.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }

    /// Two providers are equal if they have the same identifier.
    ///
    /// This ensures that the same provider instance is treated as a single entity
    /// throughout the application.
    public static func == (lhs: Provider, rhs: Provider) -> Bool {
        lhs._id == rhs._id
    }
}
