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
    
    // Nodes that depend on this node
    public var dependents: Set<ProviderID> = []
    
    // Number of SwiftUI views or external listeners
    public private(set) var listenersCount: Int = 0
    
    public func incrementListeners() {
        listenersCount += 1
        if listenersCount == 1 {
            notifyResume()
        }
    }
    
    private func notifyResume() {
        onResumeCallbacks.forEach { $0() }
    }
    
    public func decrementListeners() {
        guard listenersCount > 0 else { return }
        listenersCount -= 1
        if listenersCount == 0 {
            onCancelCallbacks.forEach { $0() }
        }
    }
    
    // Nodes that this node depends on
    @ObservationIgnored
    private var dependencies: Set<ProviderID> = []
    
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
        
        runDisposeCallbacks()
        
        let newState = providerCreate()
        
        if let box = stateBox {
            box.value = newState
        } else {
            stateBox = StateBox(newState)
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
        stateBox = nil
    }
    
    private func runDisposeCallbacks() {
        onDisposeCallbacks.forEach { $0() }
        onDisposeCallbacks.removeAll()
        onCancelCallbacks.removeAll()
        onResumeCallbacks.removeAll()
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
    
    public func onDispose(_ cleanup: @escaping () -> Void) {
        onDisposeCallbacks.append(cleanup)
    }
    
    public func onCancel(_ callback: @escaping () -> Void) {
        onCancelCallbacks.append(callback)
    }
    
    public func onResume(_ callback: @escaping () -> Void) {
        onResumeCallbacks.append(callback)
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
