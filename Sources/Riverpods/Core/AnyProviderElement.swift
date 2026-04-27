import Foundation

/// Interface type-erased cho ProviderElement.
@MainActor
public protocol AnyProviderElement: AnyObject {
    var dependents: Set<ProviderID> { get set }
    var listenersCount: Int { get }
    func incrementListeners()
    func decrementListeners()
    func invalidate()
    func performUpdate()
    func notifyDependents()
    func dispose()
}
