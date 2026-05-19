import Foundation
import Observation

// MARK: - WeakElementRef

/// A weak wrapper around an AnyProviderElement for dependency tracking.
///
/// Used by `notifyDependents()` to avoid dictionary lookups in the container.
/// Dangling nil references are cleaned up lazily on the next notification.
private struct WeakElementRef {
    weak var element: (any AnyProviderElement)?
    init(_ element: any AnyProviderElement) { self.element = element }
}

// MARK: - ProviderElement

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

    /// Cached weak references to dependent elements (avoid dictionary lookup in notifyDependents).
    @ObservationIgnored
    private var _dependentRefs: [WeakElementRef] = []

    // MARK: - Lifecycle Callbacks

    private enum CbType: Hashable { case dispose, cancel, resume, addListener, removeListener }

    /// Lifecycle callbacks, allocated lazily. 99% of elements never use them.
    @ObservationIgnored
    private var _callbacks: [CbType: [() -> Void]]?

    // MARK: - Dependency Tracking

    @ObservationIgnored
    public var dependents: Set<ProviderID> = []

    public private(set) var listenersCount: Int = 0

    @ObservationIgnored
    private var externalListeners: [UUID: (P.State?, P.State) -> Void] = [:]

    @ObservationIgnored
    private var keepAliveLinksCount = 0

    @ObservationIgnored
    private var disposeDelayTask: Task<Void, Never>?

    /// Whether this element is currently kept alive
    public var isKeepAlive: Bool { keepAliveLinksCount > 0 }
    
    // MARK: - Listener Management

    public func incrementListeners() {
        listenersCount += 1
        if listenersCount == 1 {
            fireCallbacks(.addListener)
            fireCallbacks(.resume)
        }
    }

    public func decrementListeners() {
        guard listenersCount > 0 else { return }
        listenersCount -= 1
        fireCallbacks(.removeListener)

        if listenersCount == 0 {
            fireCallbacks(.cancel)

            if provider.autoDispose && provider.cacheTime > 0 {
                disposeDelayTask = Task { @MainActor in
                    do {
                        try await Task.sleep(nanoseconds: UInt64(provider.cacheTime * 1_000_000_000))
                        guard !Task.isCancelled else { return }
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
        if stateBox == nil {
            recompute()
            if listenersCount > 0 { fireCallbacks(.resume) }
        }
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
        if container._recomputePathSet.contains(id) {
            #if DEBUG
            assertionFailure("Circular dependency detected involving: \(id)")
            #endif
            return stateBox?.value ?? providerCreate()
        }

        container.recomputePath.append(id)
        container._recomputePathSet.insert(id)
        defer {
            container.recomputePath.removeLast()
            container._recomputePathSet.remove(id)
        }

        let oldState = stateBox?.value

        // Clear callbacks (they're one-time use per computation)
        runDisposeCallbacks()

        // Compute new state
        let newState = providerCreate()

        // Skip notification if old and new are equal (via any Equatable)
        if let oldState = oldState,
           let oldEq = oldState as? any Equatable,
           let newEq = newState as? any Equatable {
            func isEqual<T: Equatable>(_ lhs: T, _ rhs: any Equatable) -> Bool {
                guard let rhs = rhs as? T else { return false }
                return lhs == rhs
            }
            if isEqual(oldEq, newEq) {
                return stateBox!.value
            }
        }

        // Update cache and notify container
        if let box = stateBox {
            let actualOldState = box.value
            box.value = newState
            container.notifyProviderUpdated(provider: provider, oldValue: actualOldState, newValue: newState)
        } else {
            stateBox = StateBox(newState)
        }

        if let oldState = oldState, !externalListeners.isEmpty {
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
    public func notifyDependents() {
        var needsCleanup = false
        for ref in _dependentRefs {
            if let el = ref.element {
                el.invalidate()
            } else {
                needsCleanup = true
            }
        }
        if needsCleanup {
            _dependentRefs.removeAll { $0.element == nil }
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

        for depID in dependencies {
            if let depElement = container.element(for: depID) {
                depElement.dependents.remove(id)
            }
        }
        dependencies.removeAll()

        internalSubscriptions.forEach { $0.close() }
        internalSubscriptions.removeAll()

        stateBox = nil
        _dependentRefs.removeAll()
    }

    private func fireCallbacks(_ type: CbType) {
        guard let arr = _callbacks?[type], !arr.isEmpty else { return }
        for cb in arr { cb() }
    }

    private func runDisposeCallbacks() {
        fireCallbacks(.dispose)
        _callbacks = nil
    }

    private func appendCallback(_ type: CbType, _ cb: @escaping () -> Void) {
        if _callbacks == nil { _callbacks = [:] }
        _callbacks![type, default: []].append(cb)
    }
    
    // MARK: - ProviderRef
    
    public func watch<Dep: ProviderProtocol>(_ depProvider: Dep) -> Dep.State {
        let depID = ProviderID(depProvider)
        dependencies.insert(depID)
        
        let depElement = container.ensureElement(for: depProvider)
        depElement.dependents.insert(id)
        depElement._addDependentRef(self)
        
        return (depElement as! ProviderElement<Dep>).getState()
    }

    public func _addDependentRef(_ element: AnyObject) {
        guard let providerElement = element as? (any AnyProviderElement) else { return }
        _dependentRefs.append(WeakElementRef(providerElement))
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

    public func onDispose(_ cleanup: @escaping () -> Void) { appendCallback(.dispose, cleanup) }
    public func onCancel(_ callback: @escaping () -> Void) { appendCallback(.cancel, callback) }
    public func onResume(_ callback: @escaping () -> Void) { appendCallback(.resume, callback) }
    public func onAddListener(_ callback: @escaping () -> Void) { appendCallback(.addListener, callback) }
    public func onRemoveListener(_ callback: @escaping () -> Void) { appendCallback(.removeListener, callback) }
    
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
