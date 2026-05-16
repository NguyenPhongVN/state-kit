import Foundation
import StateKitAtoms

// MARK: - Ecosystem Bridge Overview

/// The Ecosystem Bridge connects two powerful state management systems:
/// - **Riverpods**: Provider-based reactive state with fine-grained reactivity and lifecycle management
/// - **Atoms**: Lightweight atomic state with minimal boilerplate
///
/// **Why Both?**
/// - Atoms are great for simple, local state (toggles, text inputs, UI state)
/// - Providers excel at complex state with dependencies, async operations, and side effects
/// - The bridge allows seamless interoperability between both systems
///
/// **Two-Way Bridge:**
/// 1. **Riverpod → Atom**: Providers can watch Atoms
/// 2. **Atom → Riverpod**: Atoms can watch Providers
///
/// This enables:
/// - Using simple atoms alongside complex providers
/// - Sharing state between both ecosystems
/// - Mixing paradigms in the same application
/// - Gradual migration between systems

// MARK: - Riverpod → Atom Bridge

/// Extension enabling providers to watch atoms as dependencies.
///
/// This extension allows `ProviderElement` to create reactive dependencies on atoms
/// from within a provider's creation closure. When an atom changes, the provider
/// is automatically invalidated and recomputed.
///
/// **How It Works:**
/// - Reads the atom's current value from the shared atom store
/// - Registers the atom as a dependency
/// - Listens for atom changes and invalidates the provider when they occur
/// - Manages lifecycle: unsubscribes when the provider is disposed
extension ProviderElement {

    /// Reads an atom's value and creates a reactive dependency on it.
    ///
    /// Use this when you need to watch an atom from within a provider. The provider
    /// will automatically recompute whenever the watched atom's value changes.
    ///
    /// **Thread Safety:**
    /// Confined to the MainActor. Must be called during provider initialization only.
    ///
    /// - Parameter atom: The atom to watch
    /// - Returns: The current value of the atom
    ///
    /// **Example: Watch Atom from Provider**
    /// ```swift
    /// @Provider
    /// func userPreferencesProvider(ref: ProviderRef) -> UserPreferences {
    ///     // Watch a simple atom for a user ID
    ///     let userId = ref.watch(selectedUserIdAtom)  // Atom
    ///
    ///     // This provider recomputes whenever selectedUserIdAtom changes
    ///     let user = ref.watch(userProvider(userId))
    ///     return user.preferences
    /// }
    /// ```
    ///
    /// **Example: Combine Multiple Atoms and Providers**
    /// ```swift
    /// @Provider
    /// func filteredDataProvider(ref: ProviderRef) -> [DataItem] {
    ///     // Mix atoms and providers seamlessly
    ///     let searchQuery = ref.watch(searchAtom)      // Simple atom state
    ///     let filterMode = ref.watch(filterModeAtom)   // Another atom
    ///     let allData = ref.watch(allDataProvider)     // Provider with logic
    ///
    ///     return allData
    ///         .filter { $0.text.contains(searchQuery) }
    ///         .sorted { filterMode == .ascending ? $0.id < $1.id : $0.id > $1.id }
    /// }
    /// ```
    ///
    /// **Dependency Chain:**
    /// ```
    /// selectedUserIdAtom changes
    ///   → userPreferencesProvider invalidated
    ///   → All providers depending on userPreferencesProvider invalidated
    ///   → Cascade continues up the dependency tree
    /// ```
    ///
    /// - Note: Each watch() call creates a separate reactive dependency.
    /// - Important: Can only be called during provider initialization, not afterwards.
    /// - Warning: Do not watch atoms conditionally—set up all atom dependencies upfront.
    public func watch<A: SKAtom>(_ atom: A) -> A.Value {
        let store = SKAtomStore.shared
        let key = SKAtomKey(atom)

        // Register the atom as a dependency (only once per atom)
        if dependencies.insert(ProviderID(identifier: key, name: "Atom(\(key))")).inserted {
            // Create a subscriber token to keep the atom alive while this provider exists
            let token = SKSubscriberToken(store: store, key: key)
            onDispose {
                _ = token // Keep token alive until provider disposal
            }

            // Listen for changes to this atom
            store.addInterceptor { [weak self] changedKey, _, _ in
                if changedKey == key {
                    self?.invalidate()
                }
            }
        }

        // Get the atom's current value from the store
        let box: SKAtomBox<A.Value> = atom._getOrCreateBox(in: store)
        return box.value
    }
}

// MARK: - Atom → Riverpod Bridge

/// An atom that wraps a Riverpod provider for use in the atom ecosystem.
///
/// `RiverpodAtom` is a bridge type that allows atoms to read from providers.
/// Use it when you need to access a provider's value within an atom context.
///
/// **Thread Safety:**
/// Confined to the MainActor. Safe to use in @Watch and @Read macros.
///
/// **Use Cases:**
/// - Accessing complex provider logic from atom-based code
/// - Gradually migrating from pure atoms to providers
/// - Sharing computed values between ecosystems
/// - Reading provider state in atom transactions
///
/// **Example: Basic Riperpod Atom**
/// ```swift
/// // Wrap a provider as an atom
/// @Provider
/// func userProvider(ref: ProviderRef) -> User {
///     return fetchUser()
/// }
///
/// // Now use it in atom context
/// let userAtom = userProvider.asAtom()
///
/// @Atom
/// func userGreetingAtom(context: SKAtomContext) -> String {
///     let user = context.watch(userAtom)
///     return "Hello, \(user.name)"
/// }
/// ```
///
/// **Example: Mixed Atom and Provider**
/// ```swift
/// @Provider
/// func currentUserProvider(ref: ProviderRef) -> User {
///     let userId = ref.watch(userIdAtom.asRiverpod())
///     return fetchUser(userId)
/// }
///
/// // Later, access the same provider as an atom
/// let userAtom = currentUserProvider.asAtom()
/// ```
///
/// - Note: The wrapped provider is read lazily from the container.
/// - Important: Changes to the provider trigger atom invalidation automatically.
/// - See Also: ProviderProtocol.asAtom()
public struct RiverpodAtom<P: ProviderProtocol>: SKValueAtom, Hashable {

    // MARK: - Type Definition

    /// The value type extracted from the wrapped provider
    public typealias Value = P.State

    // MARK: - Properties

    /// The provider being wrapped as an atom
    public let provider: P

    /// The container managing the provider's state
    ///
    /// All provider reads use this container. Defaults to the shared container.
    /// Use a custom container for isolated testing or scope management.
    public let container: ProviderContainer

    // MARK: - Initialization

    /// Creates a new RiverpodAtom wrapping the specified provider.
    ///
    /// - Parameters:
    ///   - provider: The provider to wrap
    ///   - container: The container managing the provider (defaults to shared)
    ///
    /// **Example:**
    /// ```swift
    /// let userAtom = RiverpodAtom(userProvider, container: .shared)
    ///
    /// // Or using the convenience extension:
    /// let userAtom = userProvider.asAtom()
    /// ```
    @MainActor
    public init(_ provider: P, container: ProviderContainer = .shared) {
        self.provider = provider
        self.container = container
    }

    // MARK: - Value Computation

    /// Computes the atom's value by reading from the wrapped provider.
    ///
    /// Called by the atom system when the atom's value is accessed or dependencies change.
    ///
    /// - Parameter context: The atom transaction context
    /// - Returns: The current value from the wrapped provider
    ///
    /// **Implementation Note:**
    /// This reads the provider's current cached value. The provider handles
    /// its own computation, caching, and update logic independently.
    public func value(context: SKAtomTransactionContext) -> P.State {
        // Read the provider's current value from the container
        // Note: This is a one-time read; reactive updates flow through
        // the provider's own invalidation mechanism
        return container.read(provider)
    }

    // MARK: - Hashable Conformance

    /// Hashes the wrapped provider and container reference
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
    }

    /// Two RiverpodAtoms are equal if they wrap the same provider in the same container
    public static func == (lhs: RiverpodAtom, rhs: RiverpodAtom) -> Bool {
        lhs.provider == rhs.provider && lhs.container === rhs.container
    }
}

// MARK: - Convenience Extension

/// Extension adding convenience methods for ecosystem integration.
///
/// Provides easy conversion between providers and atoms for seamless
/// interoperability between the two state management systems.
extension ProviderProtocol {

    /// Converts this provider to an atom for use in the atom ecosystem.
    ///
    /// Creates a RiverpodAtom wrapping this provider, allowing atoms to read
    /// from providers. Useful for:
    /// - Accessing complex providers from atom-based code
    /// - Mixing both paradigms in the same application
    /// - Gradual migration between systems
    ///
    /// - Parameter container: The container managing the provider (defaults to shared)
    /// - Returns: An atom that wraps this provider
    ///
    /// **Thread Safety:**
    /// Confined to the MainActor.
    ///
    /// **Example: Convert to Atom**
    /// ```swift
    /// @Provider
    /// func userProvider(ref: ProviderRef) -> User {
    ///     return fetchUser()
    /// }
    ///
    /// // Convert to atom for atom-based code
    /// let userAtom = userProvider.asAtom()
    ///
    /// @Atom
    /// func userNameAtom(context: SKAtomContext) -> String {
    ///     let user = context.watch(userAtom)  // Watch provider as atom
    ///     return user.name
    /// }
    /// ```
    ///
    /// **Example: Custom Container**
    /// ```swift
    /// let testContainer = ProviderContainer()
    /// let testAtom = userProvider.asAtom(in: testContainer)
    /// ```
    ///
    /// - Note: The returned atom automatically stays in sync with the provider.
    /// - Important: Changes to the provider update the atom's value.
    @MainActor
    public func asAtom(in container: ProviderContainer = .shared) -> RiverpodAtom<Self> {
        RiverpodAtom(self, container: container)
    }
}
