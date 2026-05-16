import Foundation
import Observation

/// Quản lý trạng thái và vòng đời của một Provider cụ thể.
@MainActor
@Observable
open class ProviderElement<P: ProviderProtocol>: AnyProviderElement, ProviderRef {
    
    public let provider: P
    public let container: ProviderContainer
    public let id: ProviderID
    
    public var stateBox: StateBox<P.State>?
    
    @ObservationIgnored
    private var onDisposeCallbacks: [() -> Void] = []
    
    @ObservationIgnored
    private var onCancelCallbacks: [() -> Void] = []
    
    @ObservationIgnored
    private var onResumeCallbacks: [() -> Void] = []
    
    @ObservationIgnored
    private var onAddListenerCallbacks: [() -> Void] = []
    
    @ObservationIgnored
    private var onRemoveListenerCallbacks: [() -> Void] = []
    
    // Nodes that depend on this node
    public var dependents: Set<ProviderID> = []
    
    // Number of SwiftUI views or external listeners
    public private(set) var listenersCount: Int = 0
    
    // External listeners added via listen()
    @ObservationIgnored
    private var externalListeners: [UUID: (P.State?, P.State) -> Void] = [:]
    
    // Keep alive count
    @ObservationIgnored
    private var keepAliveLinksCount = 0
    
    // Dispose delay task
    @ObservationIgnored
    private var disposeDelayTask: Task<Void, Never>?
    
    public var isKeepAlive: Bool { keepAliveLinksCount > 0 }
    
    public func incrementListeners() {
        disposeDelayTask?.cancel()
        disposeDelayTask = nil
        
        listenersCount += 1
        if listenersCount == 1 {
            onAddListenerCallbacks.forEach { $0() }
            notifyResume()
        }
    }
    
    private func notifyResume() {
        onResumeCallbacks.forEach { $0() }
    }
    
    public func decrementListeners() {
        guard listenersCount > 0 else { return }
        listenersCount -= 1
        onRemoveListenerCallbacks.forEach { $0() }
        
        if listenersCount == 0 {
            onCancelCallbacks.forEach { $0() }
            
            // Bắt đầu đếm ngược hủy nếu có cacheTime
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
    
    // Nodes that this node depends on
    @ObservationIgnored
    var dependencies: Set<ProviderID> = []
    
    // Listeners managed by this provider (via ref.listen)
    @ObservationIgnored
    private var internalSubscriptions: [ProviderSubscription] = []
    
    public init(provider: P, container: ProviderContainer) {
        self.provider = provider
        self.container = container
        self.id = ProviderID(provider)
    }
    
    public func getState() -> P.State {
        let isFirstAccess = stateBox == nil
        if isFirstAccess {
            recompute()
            // If we have listeners, trigger onResume now that they are registered.
            if listenersCount > 0 {
                notifyResume()
            }
        }
        // ALWAYS access through stateBox?.value to ensure SwiftUI Observation tracking.
        return stateBox!.value
    }
    
    @discardableResult
    open func recompute() -> P.State {
        if container.recomputePath.contains(id) {
            #if DEBUG
            assertionFailure("Circular dependency detected involving: \(id)")
            #endif
            return stateBox?.value ?? providerCreate()
        }
        
        container.recomputePath.append(id)
        defer { container.recomputePath.removeLast() }
        
        let oldState = stateBox?.value
        
        runDisposeCallbacks()
        
        let newState = providerCreate()
        
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
    
    /// Wrapper cho việc gọi create của provider (phải được override bởi subclasses).
    open func providerCreate() -> P.State {
        fatalError("Subclasses must override providerCreate()")
    }
    
    public func invalidate() {
        // Thông báo cho container rằng mình đã thay đổi
        container.notifyProviderChanged(id: id)
    }
    
    public func performUpdate() {
        recompute()
        
        // notifyDependents is handled by container batching or manual call
        notifyDependents()
    }
    
    public func notifyDependents() {
        for dependentID in dependents {
            if let element = container.element(for: dependentID) {
                element.invalidate()
            }
        }
    }
    
    public func dispose() {
        runDisposeCallbacks()
        
        // Remove ourselves from all dependencies' dependents lists
        for depID in dependencies {
            if let depElement = container.element(for: depID) {
                depElement.dependents.remove(id)
            }
        }
        dependencies.removeAll()
        
        internalSubscriptions.forEach { $0.close() }
        internalSubscriptions.removeAll()
        
        stateBox = nil
    }
    
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

/// Một container nhỏ gọn để chứa giá trị và hỗ trợ Observation.
@Observable
public final class StateBox<T> {
    public var value: T
    public init(_ value: T) {
        self.value = value
    }
}
