import Foundation
import Observation

// MARK: - ProviderElement

/// Base class managing the lifecycle, state, and dependencies of a provider.
///
/// `ProviderElement` is the runtime representation of a provider. It's responsible for:
/// - Computing and caching the provider's state
/// - Managing dependencies between providers
/// - Tracking listeners (views, external subscribers)
/// - Controlling lifecycle callbacks (onDispose, onCancel, onResume, etc.)
/// - Implementing the ProviderRef interface for accessing other providers
/// - Coordinating with the container for updates and disposal
///
/// **Key Responsibilities:**
/// - **State Management**: Computes, caches, and updates the provider's value
/// - **Dependency Tracking**: Maintains explicit dependencies and dependents
/// - **Listener Management**: Tracks views and external listeners
/// - **Lifecycle Control**: Manages all lifecycle callbacks
/// - **Keep-Alive**: Supports preventing auto-disposal via keep-alive links
/// - **Observation Integration**: Uses SwiftUI Observation for state changes
///
/// **Thread Safety:**
/// Confined to the MainActor. All operations occur on the main thread.
///
/// **Lifecycle:**
/// 1. Created: ProviderElement instantiated when provider first accessed
/// 2. Initialized: getState() called, providerCreate() runs, state cached
/// 3. Active: Listeners register/unregister, dependents notified of changes
/// 4. Disposal: dispose() called, cleanup callbacks run, resources released
///
/// **Subclass Pattern:**
/// Concrete provider types (Provider, StateProvider, FutureProvider, etc.) create
/// specialized subclasses that override `providerCreate()` to compute state
/// appropriate for that provider type.
///
/// - Note: This is primarily an internal framework class. Rarely used directly.
/// - Important: All subclasses must override `providerCreate()`
@MainActor
@Observable
open class ProviderElement<P: ProviderProtocol>: AnyProviderElement, ProviderRef {

    // MARK: - Properties

    /// The provider this element manages
    public let provider: P

    /// The container coordinating all providers
    public let container: ProviderContainer

    /// Unique identifier for this element
    public let id: ProviderID

    /// The cached state value wrapped in an observable box
    ///
    /// Uses StateBox to integrate with SwiftUI Observation protocol.
    /// Nil until first access or computation.
    public var stateBox: StateBox<P.State>?

    // MARK: - Lifecycle Callbacks

    /// Callbacks to run when the provider is disposed or recomputed
    @ObservationIgnored
    private var onDisposeCallbacks: [() -> Void] = []

    /// Callbacks to run when all listeners stop watching
    @ObservationIgnored
    private var onCancelCallbacks: [() -> Void] = []

    /// Callbacks to run when listeners return after cancellation
    @ObservationIgnored
    private var onResumeCallbacks: [() -> Void] = []

    /// Callbacks to run when the first listener is added
    @ObservationIgnored
    private var onAddListenerCallbacks: [() -> Void] = []

    /// Callbacks to run when a listener is removed
    @ObservationIgnored
    private var onRemoveListenerCallbacks: [() -> Void] = []

    // MARK: - Dependency Tracking

    /// The set of providers depending on this element
    ///
    /// When this element's value changes, all dependents are invalidated.
    /// Updated automatically as other providers call watch().
    public var dependents: Set<ProviderID> = []

    /// Number of active listeners (views, external subscribers)
    ///
    /// - 0: No one listening; may be disposed if autoDispose is true
    /// - > 0: Active listeners; provider kept alive
    public private(set) var listenersCount: Int = 0

    /// External listeners registered via listen() method
    ///
    /// Each listener is called with (oldValue, newValue) when state changes.
    @ObservationIgnored
    private var externalListeners: [UUID: (P.State?, P.State) -> Void] = [:]

    /// Number of active keep-alive links
    ///
    /// When > 0, the provider is kept alive regardless of listeners.
    @ObservationIgnored
    private var keepAliveLinksCount = 0

    /// Task handling deferred disposal after cache time expires
    @ObservationIgnored
    private var disposeDelayTask: Task<Void, Never>?

    /// Whether this element is currently kept alive
    public var isKeepAlive: Bool { keepAliveLinksCount > 0 }
    
    // MARK: - Listener Management

    /// Increments the listener count and triggers resume callbacks if needed.
    ///
    /// Called when a new listener (view, external subscriber) starts watching.
    ///
    /// **Side Effects:**
    /// - Increments listenersCount
    /// - Cancels any pending disposal
    /// - When count transitions 0 → 1:
    ///   - Calls onAddListener callbacks
    ///   - Calls onResume callbacks
    public func incrementListeners() {
        disposeDelayTask?.cancel()
        disposeDelayTask = nil

        listenersCount += 1
        if listenersCount == 1 {
            onAddListenerCallbacks.forEach { $0() }
            notifyResume()
        }
    }

    /// Notifies that listeners have resumed after cancellation.
    ///
    /// Called when the listener count transitions from 0 to positive,
    /// triggering any onResume callbacks that were registered.
    private func notifyResume() {
        onResumeCallbacks.forEach { $0() }
    }

    /// Decrements the listener count and triggers cancel callbacks if needed.
    ///
    /// Called when a listener (view, external subscriber) stops watching.
    ///
    /// **Side Effects:**
    /// - Decrements listenersCount
    /// - Calls onRemoveListener callbacks
    /// - When count transitions to 0:
    ///   - Calls onCancel callbacks
    ///   - Schedules disposal if autoDispose and cacheTime > 0
    public func decrementListeners() {
        guard listenersCount > 0 else { return }
        listenersCount -= 1
        onRemoveListenerCallbacks.forEach { $0() }

        if listenersCount == 0 {
            onCancelCallbacks.forEach { $0() }

            // Schedule deferred disposal if cacheTime is set
            if provider.autoDispose && provider.cacheTime > 0 {
                disposeDelayTask = Task { @MainActor in
                    do {
                        try await Task.sleep(nanoseconds: UInt64(provider.cacheTime * 1_000_000_000))
                        if Task.isCancelled { return }
                        self.container.checkAutoDispose(id: self.id, element: self, provider: self.provider)
                    } catch {}
                }
            }
        }
    }
    
    // MARK: - Dependencies

    /// The set of providers this element depends on
    ///
    /// Updated as watch() is called during providerCreate().
    /// Used for cleanup: when this element is disposed, it removes itself
    /// from the dependents of all its dependencies.
    @ObservationIgnored
    var dependencies: Set<ProviderID> = []

    /// Subscriptions to external listeners created via listen()
    ///
    /// Managed automatically; closed when the element is disposed.
    @ObservationIgnored
    private var internalSubscriptions: [ProviderSubscription] = []

    // MARK: - Initialization

    /// Initializes a provider element.
    ///
    /// - Parameters:
    ///   - provider: The provider this element represents
    ///   - container: The container managing all providers
    public init(provider: P, container: ProviderContainer) {
        self.provider = provider
        self.container = container
        self.id = ProviderID(provider)
    }

    // MARK: - State Access

    /// Gets the provider's current state, computing it if necessary.
    ///
    /// **Behavior:**
    /// - First access: Calls recompute() to compute initial state
    /// - Subsequent accesses: Returns cached state
    /// - Always accesses via stateBox for SwiftUI Observation tracking
    ///
    /// - Returns: The provider's current state value
    public func getState() -> P.State {
        let isFirstAccess = stateBox == nil
        if isFirstAccess {
            recompute()
            // Trigger onResume if listeners already registered
            if listenersCount > 0 {
                notifyResume()
            }
        }
        // ALWAYS access via stateBox to enable SwiftUI Observation tracking
        return stateBox!.value
    }

    // MARK: - State Computation

    /// Computes or recomputes the provider's state.
    ///
    /// **Behavior:**
    /// - Runs providerCreate() to compute new state
    /// - Detects circular dependencies
    /// - Updates cache and notifies dependents
    /// - Calls external listeners with old/new values
    /// - Clears lifecycle callbacks
    ///
    /// **Circular Dependency Detection:**
    /// Uses a recomputePath stack in the container to detect and prevent
    /// infinite recomputation loops.
    ///
    /// - Returns: The newly computed state value
    @discardableResult
    open func recompute() -> P.State {
        // Detect circular dependencies
        if container.recomputePath.contains(id) {
            #if DEBUG
            assertionFailure("Circular dependency detected involving: \(id)")
            #endif
            return stateBox?.value ?? providerCreate()
        }

        container.recomputePath.append(id)
        defer { container.recomputePath.removeLast() }

        let oldState = stateBox?.value

        // Clear callbacks (they're one-time use per computation)
        runDisposeCallbacks()

        // Compute new state
        let newState = providerCreate()

        // Update cache and notify container
        if let box = stateBox {
            let actualOldState = box.value
            box.value = newState
            container.notifyProviderUpdated(provider: provider, oldValue: actualOldState, newValue: newState)
        } else {
            stateBox = StateBox(newState)
        }

        // Notify external listeners
        if let oldState = oldState {
            for listener in externalListeners.values {
                listener(oldState, newState)
            }
        }

        return stateBox!.value
    }

    /// Computes the provider's value. Must be overridden by subclasses.
    ///
    /// This is called by recompute() to get the new state value.
    /// Concrete provider types override this to compute state appropriate
    /// for that provider type (sync, async, stateful, etc.).
    ///
    /// - Returns: The computed state value
    /// - Important: Must be overridden in all subclasses
    open func providerCreate() -> P.State {
        fatalError("Subclasses must override providerCreate()")
    }
    
    /// Marks the provider as invalidated (state is stale).
    ///
    /// Called when:
    /// - A watched dependency changes
    /// - Cache time expires
    /// - Manual invalidation requested
    ///
    /// Notifies the container so it can batch updates.
    public func invalidate() {
        container.notifyProviderChanged(id: id)
    }

    /// Recomputes the state and notifies dependents.
    ///
    /// Used during the update phase to recompute this provider and
    /// cascade updates to all dependent providers.
    public func performUpdate() {
        recompute()
        notifyDependents()
    }

    /// Notifies all dependent providers that this element has changed.
    ///
    /// Called when the value actually changes (not just invalidated).
    /// Invalidates all dependent providers in the dependency graph.
    public func notifyDependents() {
        for dependentID in dependents {
            if let element = container.element(for: dependentID) {
                element.invalidate()
            }
        }
    }

    /// Disposes the provider and cleans up all resources.
    ///
    /// **Side Effects:**
    /// - Runs onDispose callbacks
    /// - Removes from all dependencies' dependent lists
    /// - Closes internal listener subscriptions
    /// - Releases cached state
    /// - Cannot be used after disposal
    public func dispose() {
        runDisposeCallbacks()

        // Unregister from dependencies
        for depID in dependencies {
            if let depElement = container.element(for: depID) {
                depElement.dependents.remove(id)
            }
        }
        dependencies.removeAll()

        // Close internal subscriptions
        internalSubscriptions.forEach { $0.close() }
        internalSubscriptions.removeAll()

        stateBox = nil
    }

    /// Runs and clears all lifecycle callbacks.
    ///
    /// Callbacks are one-time use; this clears them after running.
    private func runDisposeCallbacks() {
        onDisposeCallbacks.forEach { $0() }
        onDisposeCallbacks.removeAll()
        onCancelCallbacks.removeAll()
        onResumeCallbacks.removeAll()
        onAddListenerCallbacks.removeAll()
        onRemoveListenerCallbacks.removeAll()
    }
    
    // MARK: - ProviderRef
    
    public func watch<Dep: ProviderProtocol>(_ depProvider: Dep) -> Dep.State {
        let depID = ProviderID(depProvider)
        dependencies.insert(depID)
        
        let depElement = container.ensureElement(for: depProvider)
        depElement.dependents.insert(id)
        
        return (depElement as! ProviderElement<Dep>).getState()
    }
    
    public func read<Dep: ProviderProtocol>(_ depProvider: Dep) -> Dep.State {
        return container.read(depProvider)
    }
    
    public func listen<Dep: ProviderProtocol>(
        _ depProvider: Dep,
        fireImmediately: Bool = false,
        listener: @escaping (Dep.State?, Dep.State) -> Void
    ) {
        let subscription = container.listen(depProvider, fireImmediately: fireImmediately, listener: listener)
        internalSubscriptions.append(subscription)
    }

    public func onDispose(_ cleanup: @escaping () -> Void) {
        onDisposeCallbacks.append(cleanup)
    }
    
    public func onCancel(_ callback: @escaping () -> Void) {
        onCancelCallbacks.append(callback)
    }
    
    public func onResume(_ callback: @escaping () -> Void) {
        onResumeCallbacks.append(callback)
    }
    
    public func onAddListener(_ callback: @escaping () -> Void) {
        onAddListenerCallbacks.append(callback)
    }
    
    public func onRemoveListener(_ callback: @escaping () -> Void) {
        onRemoveListenerCallbacks.append(callback)
    }
    
    public func keepAlive() -> KeepAliveLink {
        keepAliveLinksCount += 1
        return KeepAliveLink { [weak self] in
            guard let self = self else { return }
            self.keepAliveLinksCount -= 1
            self.container.checkAutoDispose(id: self.id, element: self, provider: self.provider)
        }
    }
    
    // MARK: - Internal Listener Management
    
    func addListener(fireImmediately: Bool, listener: @escaping (P.State?, P.State) -> Void) -> ProviderSubscription {
        let listenerID = UUID()
        externalListeners[listenerID] = listener
        incrementListeners()
        
        if fireImmediately {
            listener(nil, getState())
        }
        
        return ProviderSubscription { [weak self] in
            guard let self = self else { return }
            self.externalListeners.removeValue(forKey: listenerID)
            self.decrementListeners()
            self.container.checkAutoDispose(id: self.id, element: self, provider: self.provider)
        }
    }
}

// MARK: - StateBox

/// A wrapper box that holds a value and integrates with SwiftUI Observation.
///
/// `StateBox` is a minimal wrapper around a value that:
/// - Conforms to the @Observable macro for SwiftUI reactivity
/// - Allows the Observation framework to track changes
/// - Enables views to automatically rebuild when the value changes
/// - Is used by ProviderElement to store cached state
///
/// **Why StateBox?**
/// Without StateBox, ProviderElement would need complex manual observation tracking.
/// By wrapping the value in an @Observable class, SwiftUI automatically detects
/// changes when the `value` property is updated.
///
/// **Thread Safety:**
/// Confined to the MainActor.
///
/// **Example (Internal Use):**
/// ```swift
/// // In ProviderElement
/// stateBox = StateBox(initialValue)
/// // When state changes:
/// stateBox?.value = newValue  // SwiftUI automatically tracks this change
/// ```
///
/// - Note: This is an internal framework class. Not typically used directly.
/// - Important: Must be @Observable for SwiftUI integration
@Observable
public final class StateBox<T> {

    /// The wrapped value.
    ///
    /// Changes to this property are automatically tracked by SwiftUI's Observation
    /// framework, triggering view updates in any views watching this value.
    public var value: T

    /// Initializes a StateBox with an initial value.
    ///
    /// - Parameter value: The initial value to wrap
    public init(_ value: T) {
        self.value = value
    }
}
