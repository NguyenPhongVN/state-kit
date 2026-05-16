import Foundation

// MARK: - AnyProviderElement

/// A type-erased protocol for provider element implementations.
///
/// `AnyProviderElement` is the framework's internal interface for managing provider lifecycle,
/// caching, and notification. It abstracts away the specific provider type to allow the container
/// to manage providers uniformly, regardless of whether they're synchronous (Provider),
/// asynchronous (FutureProvider), notifiers (NotifierProvider), or other implementations.
///
/// **Thread Safety:**
/// Confined to the MainActor. All operations must occur on the main thread.
/// The protocol ensures thread-safe management of provider state and listener notifications.
///
/// **Lifecycle Overview:**
/// Each element manages:
/// - **Creation**: Computing and caching the provider's initial value
/// - **Dependencies**: Tracking which providers depend on this element
/// - **Listeners**: Counting active watchers to determine if the provider is in use
/// - **Invalidation**: Marking the cached value as stale when dependencies change
/// - **Updates**: Recomputing values and notifying dependents when needed
/// - **Disposal**: Cleaning up resources when the provider is no longer needed
///
/// **Key Responsibilities:**
/// - Store and manage the provider's computed value in `stateBox`
/// - Track dependents that need notification when this provider changes
/// - Manage listener count to determine if the provider should be kept alive
/// - Implement caching and lazy evaluation strategies
/// - Notify dependents when the value changes
///
/// **Internal Use:**
/// This protocol is internal to the framework. Typically accessed through:
/// - `ProviderContainer.getElement()` - Retrieve element for a provider
/// - `ProviderElement<P>` - Base implementation for all concrete elements
/// - Specific implementations: `SimpleProviderElement`, `FutureProviderElement`, etc.
///
/// **Example: Element Lifecycle (Internal)**
/// ```swift
/// // This is handled internally by the framework
/// let element = provider.createElement(container: container) as AnyProviderElement
///
/// // Listener subscribes
/// element.incrementListeners()  // Increases active listener count
///
/// // Provider value changes (dependency updated)
/// element.invalidate()           // Mark as stale
/// element.performUpdate()        // Recompute if needed
/// element.notifyDependents()     // Notify dependent providers
///
/// // Listener unsubscribes
/// element.decrementListeners()   // Decreases listener count
///
/// // If no more listeners and autoDispose is true
/// element.dispose()              // Clean up resources
/// ```
///
/// - Note: This protocol is part of the framework's internal architecture and should not be implemented directly.
/// - Important: All implementations must be confined to the MainActor for thread safety.
@MainActor
public protocol AnyProviderElement: AnyObject {

    // MARK: - State Management

    /// The set of provider IDs that depend on this element.
    ///
    /// When this element's value changes, all providers in this set are invalidated.
    /// The framework automatically manages this set as dependencies are discovered
    /// through `watch()` calls in provider creation closures.
    ///
    /// **Usage:**
    /// - Modified when a dependent provider calls `watch()`
    /// - Cleared during disposal
    /// - Iterated when notifying dependents of changes
    ///
    /// - Note: This is managed internally and should not be modified directly.
    var dependents: Set<ProviderID> { get set }

    /// The number of active listeners (views or other providers) watching this element.
    ///
    /// - **0**: No one is watching; provider may be disposed if `autoDispose` is true
    /// - **> 0**: One or more listeners are actively watching the provider
    ///
    /// This count is used to:
    /// - Determine if the provider is in use
    /// - Trigger `onCancel` when count reaches 0
    /// - Trigger `onResume` when count goes from 0 to 1
    /// - Decide whether to keep the provider alive
    ///
    /// **Example (Internal):**
    /// ```swift
    /// // When a view starts watching the provider
    /// element.incrementListeners()  // 0 → 1, triggers onResume if needed
    ///
    /// // When another view starts watching
    /// element.incrementListeners()  // 1 → 2
    ///
    /// // When first view stops watching
    /// element.decrementListeners()  // 2 → 1
    ///
    /// // When last view stops watching
    /// element.decrementListeners()  // 1 → 0, triggers onCancel
    /// ```
    ///
    /// - Note: The framework automatically maintains this count.
    var listenersCount: Int { get }

    /// Whether this element is kept alive and will not be disposed.
    ///
    /// When true, the provider remains in memory even if `listenersCount` reaches 0
    /// and `autoDispose` is true. This is set to true when:
    /// - `ref.keepAlive()` is called during provider initialization
    /// - An external keep-alive link is active
    ///
    /// **Lifecycle:**
    /// ```
    /// isKeepAlive = false  →  (ref.keepAlive() called)  →  isKeepAlive = true
    ///
    /// isKeepAlive = true   →  (keep-alive link closed)  →  isKeepAlive = false
    /// ```
    ///
    /// - Note: Even when keep-alive is true, disposal still occurs if explicitly requested.
    var isKeepAlive: Bool { get }

    // MARK: - Listener Management

    /// Increments the listener count and triggers lifecycle callbacks if needed.
    ///
    /// Called when a new listener (view, provider, or observer) starts watching this provider.
    ///
    /// **Side Effects:**
    /// - Increments `listenersCount`
    /// - If count transitions from 0 → 1:
    ///   - Triggers `onResume` callback (if registered)
    ///   - Triggers `onAddListener` callback
    /// - If count transitions to any positive value:
    ///   - Triggers `onAddListener` callback
    ///
    /// **Example (Internal):**
    /// ```swift
    /// // View starts watching
    /// element.incrementListeners()  // Updates listener count, triggers callbacks
    /// ```
    ///
    /// - Note: Called automatically by the framework when listeners subscribe.
    func incrementListeners()

    /// Decrements the listener count and triggers lifecycle callbacks if needed.
    ///
    /// Called when a listener (view, provider, or observer) stops watching this provider.
    ///
    /// **Side Effects:**
    /// - Decrements `listenersCount`
    /// - If count transitions from 1 → 0:
    ///   - Triggers `onCancel` callback (if registered)
    ///   - Signals that the provider is no longer actively used
    /// - If count is still positive:
    ///   - Triggers `onRemoveListener` callback
    /// - Marks the provider for potential disposal if:
    ///   - `autoDispose` is true
    ///   - `isKeepAlive` is false
    ///   - No other references exist
    ///
    /// **Example (Internal):**
    /// ```swift
    /// // View stops watching
    /// element.decrementListeners()  // Updates count, may trigger onCancel
    ///
    /// // If this was the last listener and autoDispose is true
    /// element.dispose()  // Called automatically by the container
    /// ```
    ///
    /// - Note: Called automatically by the framework when listeners unsubscribe.
    func decrementListeners()

    // MARK: - Value Management

    /// Marks this element's cached value as invalid.
    ///
    /// Invalidation occurs when:
    /// - A dependency (watched provider) changes its value
    /// - Explicit refresh is requested via `ref.invalidate()`
    /// - Cache time expires
    ///
    /// **Behavior:**
    /// - Clears or marks the cached value as stale
    /// - **Does not** immediately recompute
    /// - The value is recomputed lazily on next access
    /// - Propagates invalidation to all dependent providers
    ///
    /// **Example (Internal):**
    /// ```swift
    /// // Dependency changed
    /// dependencyElement.notifyDependents()  // Calls invalidate() on all dependents
    ///
    /// // This element is invalidated
    /// element.invalidate()  // Mark as stale, but don't recompute yet
    /// ```
    ///
    /// - Note: Invalidation is lazy. Values are recomputed only when accessed.
    /// - Important: This cascades to dependent providers automatically.
    func invalidate()

    /// Recomputes or updates this element's value if needed.
    ///
    /// Called when:
    /// - A watched dependency changes
    /// - A cache timeout expires
    /// - An explicit refresh is triggered
    ///
    /// **Behavior:**
    /// - For simple providers: Recomputes the value by calling the creation closure
    /// - For async providers: Updates state (may still be loading)
    /// - For notifiers: Updates internal state
    /// - Handles value transformation and memoization
    /// - **May or may not** notify dependents (depends on whether value actually changed)
    ///
    /// **Example (Internal):**
    /// ```swift
    /// // Dependency changed, need to recompute
    /// element.performUpdate()  // Recompute if value changed, notify if needed
    /// ```
    ///
    /// - Note: The element decides whether to notify dependents based on comparison.
    /// - Important: This is called as part of the update cycle, not directly by users.
    func performUpdate()

    /// Notifies all dependent providers that this element's value has changed.
    ///
    /// Called when:
    /// - The provider's value actually changes (not just invalidated, but truly updated)
    /// - After `performUpdate()` determines a change occurred
    /// - A manual invalidation requests notification
    ///
    /// **Side Effects:**
    /// - Calls `invalidate()` on each dependent provider
    /// - Triggers `performUpdate()` on each dependent
    /// - Cascades notifications up the dependency graph
    /// - May trigger view rebuilds if UI providers are affected
    ///
    /// **Propagation Chain:**
    /// ```
    /// sourceProvider changes
    ///   → sourceElement.notifyDependents()
    ///     → dependentElement.invalidate()
    ///     → dependentElement.performUpdate()
    ///       → (if dependent changed)
    ///       → dependentElement.notifyDependents()
    ///         → (cascade continues up the graph)
    /// ```
    ///
    /// **Example (Internal):**
    /// ```swift
    /// // This provider's value changed
    /// element.notifyDependents()  // Alert all dependent providers
    /// ```
    ///
    /// - Note: This is part of the reactive update system.
    /// - Important: Never call this directly; the framework manages it.
    func notifyDependents()

    // MARK: - Lifecycle

    /// Disposes of this element and cleans up all resources.
    ///
    /// Called when:
    /// - Provider is no longer needed and `autoDispose` is true
    /// - Container is explicitly cleared
    /// - Application is terminating
    /// - Provider chain is being broken
    ///
    /// **Side Effects:**
    /// - Triggers `onDispose` callbacks registered via `ref.onDispose()`
    /// - Closes any open keep-alive links
    /// - Releases the cached value
    /// - Removes this element from the container
    /// - Removes all dependent relationships
    /// - Stops listening to dependencies
    ///
    /// **Resource Cleanup:**
    /// ```swift
    /// // Provider setup registered cleanup
    /// ref.onDispose {
    ///     timer.invalidate()       // Stop timer
    ///     websocket.close()        // Close connection
    ///     observer.removeListener() // Remove observer
    /// }
    ///
    /// // Disposal triggers all registered cleanups
    /// element.dispose()  // All above closures execute
    /// ```
    ///
    /// - Important: After disposal, the element cannot be reused. A new element must be created if the provider is accessed again.
    /// - Note: Multiple calls to dispose() are safe (idempotent).
    func dispose()
}
