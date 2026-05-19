import Foundation
import Observation

// MARK: - ProviderContainer

/// Central coordinator managing all providers in the application.
///
/// `ProviderContainer` is the heart of the Riverpods system. It:
/// - Stores and manages all provider instances (ProviderElements)
/// - Coordinates dependencies between providers
/// - Handles provider creation, caching, and disposal
/// - Manages listener registration for SwiftUI views
/// - Supports provider overrides for testing
/// - Notifies observers of provider lifecycle events
/// - Batches updates for efficient propagation
///
/// **Two Container Types:**
/// 1. **Shared Container**: Global singleton for normal app usage
/// 2. **Custom Container**: Test containers with overrides for isolated testing
///
/// **Thread Safety:**
/// Confined to the MainActor. All operations occur on the main thread.
///
/// **Key Responsibilities:**
/// - **Element Management**: Create/retrieve provider elements on demand
/// - **Dependency Coordination**: Track and invalidate dependent providers
/// - **Listener Tracking**: Register/unregister view listeners
/// - **Override Support**: Replace providers with test values
/// - **Observer Notification**: Notify listeners of lifecycle events
/// - **Update Batching**: Batch multiple updates for efficiency
/// - **Auto-disposal**: Clean up unused providers when configured
///
/// **Usage:**
/// - Usually accessed implicitly via @Watch/@Read property wrappers
/// - Direct access needed for manual listener management or testing
/// - Can be created with overrides for isolated test containers
///
/// **Example: Direct Access**
/// ```swift
/// let container = ProviderContainer.shared
/// let value = container.read(userProvider)
/// ```
///
/// **Example: Test Container with Overrides**
/// ```swift
/// let testUser = User(id: 1, name: "Test")
/// let override = userProvider.overrideWith(testUser)
/// let testContainer = ProviderContainer(overrides: [override])
/// let value = testContainer.read(userProvider)  // Gets testUser
/// ```
///
/// **Example: Listener Registration (for external updates)**
/// ```swift
/// let subscription = container.listen(dataProvider) { old, new in
///     print("Data changed from \(old) to \(new)")
/// }
/// // Later:
/// subscription.close()  // Stop listening
/// ```
///
/// - Important: Most code should use @Watch/@Read, not access container directly
/// - Note: The shared container is a global singleton
/// - Warning: Each custom container maintains separate provider state
@MainActor
@Observable
public final class ProviderContainer {

    // MARK: - Shared Instance

    /// The global shared provider container.
    ///
    /// Used by default when no custom container is specified.
    /// All providers share state through this singleton.
    public static let shared = ProviderContainer()

    // MARK: - Properties

    private var elements: [ProviderID: any AnyProviderElement] = [:]

    private let overrides: [ProviderID: ProviderOverride]

    public let parent: ProviderContainer?

    @ObservationIgnored
    private var observers: [ProviderObserver] = []

    // MARK: - Batching State

    @ObservationIgnored
    private var isBatching = false

    @ObservationIgnored
    private var pendingChanges = Set<ProviderID>()

    // MARK: - Cycle Detection

    /// Ordered path for debug traces.
    @ObservationIgnored
    var recomputePath = [ProviderID]()
    @ObservationIgnored
    var _recomputePathSet = Set<ProviderID>()
    
    // MARK: - Initialization

    /// Creates a new provider container.
    ///
    /// - Parameters:
    ///   - parent: Parent container for hierarchical lookup (optional)
    ///   - overrides: Provider overrides for testing (default: empty)
    ///   - observers: Lifecycle observers to attach (default: empty)
    ///
    /// **Example: Shared Container (Default)**
    /// ```swift
    /// // ProviderContainer.shared is used by default
    /// ```
    ///
    /// **Example: Test Container with Overrides**
    /// ```swift
    /// let testUser = User(id: 1, name: "Test")
    /// let override = userProvider.overrideWith(testUser)
    /// let testContainer = ProviderContainer(overrides: [override])
    /// ```
    ///
    /// **Example: With Observers for Logging**
    /// ```swift
    /// let logger = DebugProviderObserver()
    /// let container = ProviderContainer(observers: [logger])
    /// ```
    public init(
        parent: ProviderContainer? = nil,
        overrides: [ProviderOverride] = [],
        observers: [ProviderObserver] = []
    ) {
        self.parent = parent
        var map = [ProviderID: ProviderOverride]()
        for o in overrides {
            map[o.providerID] = o
        }
        self.overrides = map
        self.observers = observers
    }

    // MARK: - Observer Management

    /// Adds a lifecycle observer to this container.
    ///
    /// The observer will be notified when providers are added, updated, or disposed.
    ///
    /// - Parameter observer: The observer to register
    ///
    /// **Example:**
    /// ```swift
    /// let debugObserver = MyDebugObserver()
    /// container.addObserver(debugObserver)
    /// ```
    public func addObserver(_ observer: ProviderObserver) {
        observers.append(observer)
    }

    // MARK: - Element Management

    /// Gets or creates a provider element, handling overrides and parent lookup.
    ///
    /// This is the core method for provider access. It:
    /// 1. Checks if element exists in this container
    /// 2. If not, checks parent container (if exists)
    /// 3. Handles value overrides (test replacements)
    /// 4. Handles provider overrides (swap implementations)
    /// 5. Creates new element if needed
    /// 6. Notifies observers
    ///
    /// - Parameter provider: The provider to get element for
    /// - Returns: An AnyProviderElement managing the provider
    ///
    /// **Lookup Logic:**
    /// ```
    /// if element exists → return it
    /// if override exists → use override
    /// if parent exists → try parent.ensureElement()
    /// otherwise → create new element
    /// ```
    ///
    /// - Note: Typically called automatically, not directly
    public func ensureElement<P: ProviderProtocol>(for provider: P) -> AnyProviderElement {
        let id = ProviderID(provider)

        // Check if element already exists
        if let element = elements[id] {
            return element
        }

        // If no override here but parent exists, try parent
        if overrides[id] == nil, let parent = parent {
            return parent.ensureElement(for: provider)
        }

        if let overrideRecord = overrides[id], let customProvider = overrideRecord.providerOverride {
            let element = customProvider.createElement(container: self)
            elements[id] = element

            let value = (element as! ProviderElement<P>).getState()
            if !observers.isEmpty {
                for observer in observers { observer.didAddProvider(provider, value: value, container: self) }
            }
            return element
        }

        let element = provider.createElement(container: self)
        elements[id] = element

        if let overrideRecord = overrides[id], let value = overrideRecord.value, let stateElement = element as? ProviderElement<P> {
            stateElement.stateBox = StateBox(value as! P.State)
        }

        let value = (element as! ProviderElement<P>).getState()
        if !observers.isEmpty {
            for observer in observers { observer.didAddProvider(provider, value: value, container: self) }
        }

        return element
    }

    // MARK: - Provider Access

    /// Forces a provider to recompute its value immediately.
    ///
    /// Useful for refresh operations or forcing updates after external data changes.
    ///
    /// - Parameter provider: The provider to refresh
    /// - Returns: The newly computed value
    ///
    /// **Example:**
    /// ```swift
    /// let newData = container.refresh(dataProvider)
    /// ```
    @discardableResult
    public func refresh<P: ProviderProtocol>(_ provider: P) -> P.State {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        return element.recompute()
    }

    /// Reads a provider's current value without establishing reactivity.
    ///
    /// One-time read that doesn't create a listener.
    /// Useful for configuration values or conditional reads.
    ///
    /// - Parameter provider: The provider to read
    /// - Returns: The provider's current value
    ///
    /// **Example:**
    /// ```swift
    /// let config = container.read(configProvider)
    /// ```
    public func read<P: ProviderProtocol>(_ provider: P) -> P.State {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        return element.getState()
    }

    /// Watches a provider's current value.
    ///
    /// Used primarily by @Watch property wrapper internally.
    /// Direct use is rare; @Watch is preferred in SwiftUI.
    ///
    /// - Parameter provider: The provider to watch
    /// - Returns: The provider's current value
    public func watch<P: ProviderProtocol>(_ provider: P) -> P.State {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        return element.getState()
    }

    // MARK: - External Listener Management

    /// Registers an external listener for provider changes.
    ///
    /// Useful for non-SwiftUI code or complex listening scenarios.
    /// The listener is called with (oldValue, newValue) whenever the provider updates.
    ///
    /// - Parameters:
    ///   - provider: The provider to listen to
    ///   - fireImmediately: Whether to call listener with current value immediately
    ///   - listener: Closure called on each update
    /// - Returns: A subscription that can be closed to stop listening
    ///
    /// **Example:**
    /// ```swift
    /// let subscription = container.listen(userProvider, fireImmediately: true) { old, new in
    ///     print("User changed: \(new)")
    /// }
    /// // Later:
    /// subscription.close()
    /// ```
    public func listen<P: ProviderProtocol>(
        _ provider: P,
        fireImmediately: Bool = false,
        listener: @escaping (P.State?, P.State) -> Void
    ) -> ProviderSubscription {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        return element.addListener(fireImmediately: fireImmediately, listener: listener)
    }

    /// Registers a SwiftUI listener (used internally by @Watch).
    ///
    /// Called by @Watch property wrapper to establish reactivity.
    /// Not typically called directly.
    ///
    /// - Parameter provider: The provider to listen to
    /// - Returns: The current provider value
    public func addListener<P: ProviderProtocol>(for provider: P) -> P.State {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        element.incrementListeners()
        return element.getState()
    }

    /// Unregisters a SwiftUI listener (used internally by @Watch).
    ///
    /// Called when a @Watch stops watching a provider.
    /// Not typically called directly.
    ///
    /// - Parameter provider: The provider to stop listening to
    /// Unregisters a SwiftUI listener (used internally by @Watch).
    ///
    /// Called when a @Watch stops watching a provider.
    /// Not typically called directly.
    ///
    /// - Parameter provider: The provider to stop listening to
    public func removeListener<P: ProviderProtocol>(for provider: P) {
        let id = ProviderID(provider)
        guard let element = elements[id] else { return }
        element.decrementListeners()

        // Check auto-disposal if no cache time
        if provider.cacheTime <= 0 {
            checkAutoDispose(id: id, element: element, provider: provider)
        }
    }

    /// Checks and performs auto-disposal of a provider element.
    ///
    /// Automatically disposes a provider when:
    /// 1. No listeners are active (listenersCount <= 0)
    /// 2. Provider has autoDispose enabled
    /// 3. No keep-alive links exist
    /// 4. No dependents rely on this provider
    ///
    /// **Side Effects:**
    /// - Notifies observers before disposal
    /// - Calls element.dispose() to clean up resources
    /// - Removes element from the elements dictionary
    ///
    /// **When Called:**
    /// - When a listener is removed and cacheTime <= 0
    /// - From external listener subscription close
    /// - When keep-alive link is released
    /// - Allows delayed disposal after cache time expires
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the provider element
    ///   - element: The element managing the provider
    ///   - provider: The provider protocol instance
    ///
    /// **Example: Auto-Disposal Logic**
    /// ```swift
    /// // Provider with autoDispose enabled automatically cleans up
    /// // when no one is listening and it has no dependents
    /// @Provider(autoDispose: true)
    /// func tempDataProvider(ref: ProviderRef) -> Data {
    ///     return fetchTemporaryData()
    /// }
    /// // When all views stop watching tempDataProvider,
    /// // it's automatically disposed to free resources
    /// ```
    func checkAutoDispose<P: ProviderProtocol>(id: ProviderID, element: any AnyProviderElement, provider: P) {
        guard element.listenersCount <= 0 && provider.autoDispose && !element.isKeepAlive else { return }
        guard element.dependents.isEmpty else { return }

        if !observers.isEmpty {
            for observer in observers { observer.didDisposeProvider(provider, container: self) }
        }

        element.dispose()
        elements.removeValue(forKey: id)
    }

    /// Retrieves a provider element by its ID.
    ///
    /// Internal lookup method used during dependency tracking and updates.
    ///
    /// - Parameter id: The unique identifier of the provider
    /// - Returns: The element managing the provider, or nil if not present
    ///
    /// **Note:** This method is used internally by the framework.
    /// Typically accessed through type-safe methods like read(), watch(), or refresh().
    func element(for id: ProviderID) -> (any AnyProviderElement)? {
        return elements[id]
    }
    
    // MARK: - Internal Propagation

    /// Notifies the container that a provider's value has changed.
    ///
    /// Called by ProviderElement when its state is invalidated.
    /// This method collects changes and batches them for efficient propagation.
    ///
    /// **Behavior:**
    /// - Adds the provider ID to pendingChanges
    /// - If currently batching, accumulates the change
    /// - If not batching, immediately flushes accumulated changes
    /// - Allows multiple invalidations to coalesce into one update cycle
    ///
    /// **Batching Benefit:**
    /// Multiple rapid changes to different providers are batched together
    /// and processed in a single update cycle, improving performance.
    ///
    /// **Example: Automatic Batching**
    /// ```swift
    /// // Multiple provider changes batch automatically
    /// let newData = container.refresh(dataProvider)  // Triggers invalidation
    /// // All dependents notified in a single update cycle
    /// ```
    ///
    /// - Parameter id: The unique identifier of the provider that changed
    ///
    /// - Important: Internal framework method. Not typically called directly.
    func notifyProviderChanged(id: ProviderID) {
        pendingChanges.insert(id)
        if isBatching { return }
        flushChanges()
    }

    /// Notifies all observers that a provider's value was updated.
    ///
    /// Called after a provider successfully recomputes its state.
    /// Allows observers to track provider lifecycle events and perform logging,
    /// analytics, or debugging based on value changes.
    ///
    /// **Observer Notification:**
    /// Iterates through all registered observers and calls their
    /// didUpdateProvider() callback with old/new values.
    ///
    /// **Use Cases for Observers:**
    /// - Logging: Track which providers changed and when
    /// - Analytics: Measure update frequency and performance
    /// - Debugging: Inspect state transitions during development
    /// - Caching: Track external cache synchronization
    ///
    /// - Parameters:
    ///   - provider: The provider that was updated
    ///   - oldValue: The previous state value
    ///   - newValue: The new computed state value
    ///
    /// **Example: Observer Implementation**
    /// ```swift
    /// class DebugObserver: ProviderObserver {
    ///     func didUpdateProvider<P: ProviderProtocol>(
    ///         _ provider: P,
    ///         oldValue: P.State,
    ///         newValue: P.State,
    ///         container: ProviderContainer
    ///     ) {
    ///         print("\\(P.self) changed from \\(oldValue) to \\(newValue)")
    ///     }
    /// }
    /// ```
    ///
    /// - Important: Called internally during provider state updates
    func notifyProviderUpdated<P: ProviderProtocol>(provider: P, oldValue: P.State, newValue: P.State) {
        guard !observers.isEmpty else { return }
        for observer in observers {
            observer.didUpdateProvider(provider, oldValue: oldValue, newValue: newValue, container: self)
        }
    }

    // MARK: - Update Batching

    /// Batches multiple provider changes for efficient propagation.
    ///
    /// Groups provider updates together so they're processed in a single
    /// propagation cycle instead of individually. This is useful when you
    /// need to perform multiple operations that would normally trigger
    /// many updates.
    ///
    /// **Benefits of Batching:**
    /// - Reduces view rebuild count
    /// - Improves performance with many providers
    /// - Ensures consistent state during multi-step operations
    /// - Prevents intermediate inconsistent states
    ///
    /// **Behavior:**
    /// - Wraps the body closure in a batching context
    /// - Nested batches are supported (only outermost batch flushes)
    /// - All accumulated changes flush after body completes
    /// - Changes are processed in dependency order
    ///
    /// **Nested Batches:**
    /// When batches are nested, only the outermost batch flushes changes.
    /// Inner batches accumulate changes without triggering flushes.
    ///
    /// **Example: Batch Multiple Updates**
    /// ```swift
    /// container.batch {
    ///     // Multiple updates here
    ///     _ = container.refresh(userProvider)
    ///     _ = container.refresh(settingsProvider)
    ///     _ = container.refresh(notificationsProvider)
    ///
    ///     // All changes coalesce into a single update cycle
    ///     // Views only rebuild once, not three times
    /// }
    /// ```
    ///
    /// **Example: Form Submission**
    /// ```swift
    /// func submitForm(data: FormData) {
    ///     container.batch {
    ///         container.read(formProvider).state = data
    ///         container.refresh(validationProvider)
    ///         container.refresh(submitStatusProvider)
    ///     }
    /// }
    /// ```
    ///
    /// **Example: Nested Batches**
    /// ```swift
    /// container.batch {
    ///     container.batch {
    ///         // Inner batch doesn't flush
    ///     }
    ///     // Changes flush here after outer batch completes
    /// }
    /// ```
    ///
    /// - Parameter body: Closure containing operations to batch together
    public func batch(_ body: () -> Void) {
        let alreadyBatching = isBatching
        isBatching = true
        body()
        isBatching = alreadyBatching

        if !isBatching {
            flushChanges()
        }
    }

    /// Processes all accumulated provider changes.
    ///
    /// Called after batching completes or when a change occurs outside batching.
    /// Iterates through all pending provider IDs and triggers their update/recomputation,
    /// which cascades invalidation to dependent providers.
    ///
    /// **Update Cycle:**
    /// 1. Collects all pending changes from pendingChanges set
    /// 2. Clears pendingChanges to accumulate new changes during processing
    /// 3. For each changed provider, calls performUpdate()
    /// 4. Dependent providers are invalidated and added to pendingChanges
    /// 5. Repeats until no more changes pending (handles cascading updates)
    ///
    /// **Circular Update Prevention:**
    /// - Uses a while loop to handle cascading updates
    /// - Each iteration processes one "generation" of changes
    /// - Prevents infinite loops through circular dependency detection
    /// - ProviderElement.recompute() detects cycles via recomputePath
    ///
    /// **Thread Safety:**
    /// - Sets isBatching during flush to prevent nested flushes
    /// - Uses defer to ensure isBatching is cleared
    /// - Confined to the MainActor
    ///
    /// **Example: Update Propagation**
    /// ```swift
    /// // Dependency graph:
    /// // userProvider → userSettingsProvider → uiStateProvider
    ///
    /// container.refresh(userProvider)  // Invalidates userProvider
    /// // flushChanges() processes:
    /// // 1. Updates userProvider
    /// // 2. userProvider invalidates userSettingsProvider
    /// // 3. Updates userSettingsProvider
    /// // 4. userSettingsProvider invalidates uiStateProvider
    /// // 5. Updates uiStateProvider
    /// // All in a single flush cycle
    /// ```
    private func flushChanges() {
        guard !pendingChanges.isEmpty else { return }

        isBatching = true
        repeat {
            let changes = pendingChanges
            pendingChanges = []
            for id in changes {
                elements[id]?.performUpdate()
            }
        } while !pendingChanges.isEmpty
        isBatching = false
    }
}

// MARK: - ProviderSubscription

/// A token representing an active provider listener subscription.
///
/// `ProviderSubscription` is returned from `container.listen()` and allows
/// external listeners (non-SwiftUI code) to manage their subscriptions.
/// It provides an explicit `close()` method to stop listening and clean up.
///
/// **Key Characteristics:**
/// - **Owned by caller**: External listeners own the subscription token
/// - **Manual control**: Explicit close() method stops listening
/// - **Auto-cleanup**: Deinit automatically closes if not manually closed
/// - **Thread-safe**: Sendable type, works across actor boundaries
/// - **Lightweight**: Small token with just a callback
///
/// **Thread Safety:**
/// Confined to the MainActor. The closure must be @MainActor isolated.
/// The subscription itself is Sendable for safe task passing.
///
/// **Lifecycle:**
/// 1. Created: Returned from container.listen()
/// 2. Active: Listener receives notifications until closed
/// 3. Closed: close() called or subscription deinited
/// 4. Inactive: No further notifications after closure
///
/// **Use Cases:**
/// - Non-SwiftUI code listening to providers
/// - Complex listening scenarios with explicit cleanup
/// - Temporary listeners in event handlers
/// - Bridging providers to external systems
/// - Testing provider update behavior
///
/// **Example: Basic Listener Registration**
/// ```swift
/// let subscription = container.listen(userProvider) { old, new in
///     print("User changed: \\(new)")
/// }
///
/// // Later, stop listening
/// subscription.close()
/// ```
///
/// **Example: Immediate Firing**
/// ```swift
/// let subscription = container.listen(
///     dataProvider,
///     fireImmediately: true
/// ) { _, new in
///     print("Current data: \\(new)")
/// }
///
/// // Listener fires immediately with current value,
/// // then continues listening for future changes
/// subscription.close()
/// ```
///
/// **Example: Event Listener**
/// ```swift
/// let subscription = container.listen(
///     notificationsProvider
/// ) { old, new in
///     handleNotifications(new)
/// }
///
/// // Clean up when view is destroyed
/// deinit {
///     subscription.close()
/// }
/// ```
///
/// **Example: Temporary Listener in Function**
/// ```swift
/// func waitForDataLoad() async {
///     let subscription = container.listen(dataProvider) { _, new in
///         if case .data = new {
///             // Data loaded
///         }
///     }
///     // Cleanup happens automatically when subscription deinits
/// }
/// ```
///
/// - Important: Always close subscriptions when no longer needed
/// - Note: Auto-closes via deinit if not manually closed
/// - Tip: Combine with @State or property for lifecycle management
public final class ProviderSubscription: Sendable {
    /// The cleanup callback invoked when the subscription is closed.
    ///
    /// Called by close() or automatically by deinit.
    /// Must be @MainActor isolated for safe cleanup.
    private let _onClose: @MainActor () -> Void

    /// Initializes a subscription with a cleanup callback.
    ///
    /// - Parameter onClose: Closure called when subscription is closed or deinited
    init(onClose: @escaping @MainActor () -> Void) {
        self._onClose = onClose
    }

    /// Closes the subscription and stops listening to provider changes.
    ///
    /// **Side Effects:**
    /// - Calls the cleanup callback
    /// - Unregisters the listener from the element
    /// - Triggers auto-disposal checks if applicable
    /// - Prevents further listener notifications
    ///
    /// **Behavior:**
    /// - Safe to call multiple times (only first call runs cleanup)
    /// - Can be called from any actor (callback is @MainActor)
    /// - Synchronously completes cleanup
    ///
    /// **Example:**
    /// ```swift
    /// let subscription = container.listen(provider) { _, _ in }
    /// // ... use listener ...
    /// subscription.close()  // Stop listening
    /// ```
    @MainActor
    public func close() {
        _onClose()
    }

    /// Automatically closes the subscription when it's deallocated.
    ///
    /// Ensures cleanup happens even if close() is never explicitly called.
    /// Useful for RAII pattern and preventing listener leaks.
    ///
    /// **Behavior:**
    /// - Wraps cleanup in Task for MainActor safety
    /// - Guarantees cleanup runs even if close() isn't called
    /// - Safe even if subscription is on different actor
    /// - Prevents listener leaks from accidental omission
    ///
    /// **Example: Automatic Cleanup on View Destruction**
    /// ```swift
    /// var subscription: ProviderSubscription?
    ///
    /// func setupListener() {
    ///     subscription = container.listen(provider) { _, new in
    ///         handle(new)
    ///     }
    ///     // No explicit cleanup needed; deinit handles it
    /// }
    /// ```
    deinit {
        let close = _onClose
        Task { @MainActor in
            close()
        }
    }
}
