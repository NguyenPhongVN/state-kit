import Foundation
import StateKit
import Observation

// MARK: - Future Element

@MainActor
public final class FutureProviderElement<T: Sendable>: ProviderElement<FutureProvider<T>> {
    public override func providerCreate() -> AsyncValue<T> {
        let task = Task { @MainActor in
            do {
                let value = try await provider.fetch(ref: self)
                if Task.isCancelled { return }
                self.stateBox?.value = .data(value)
                self.notifyDependents()
            } catch {
                if Task.isCancelled { return }
                self.stateBox?.value = .error(error)
                self.notifyDependents()
            }
        }
        
        onDispose {
            task.cancel()
        }
        
        if let lastValue = stateBox?.value.value {
            return .refreshing(lastValue)
        }
        return .loading
    }
}

// MARK: - FutureProvider

/// Một Provider cho các tác vụ bất đồng bộ một lần.
public struct FutureProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = AsyncValue<T>
    
    private let _create: @MainActor (ProviderRef) async throws -> T
    private let _id: AnyHashable
    public let autoDispose: Bool
    
    public init(autoDispose: Bool = true, _ create: @escaping @MainActor (ProviderRef) async throws -> T) {
        self.autoDispose = autoDispose
        self._create = create
        self._id = UUID()
    }
    
    internal init(id: AnyHashable, autoDispose: Bool, create: @escaping @MainActor (ProviderRef) async throws -> T) {
        self._id = id
        self.autoDispose = autoDispose
        self._create = create
    }
    
    @MainActor
    func fetch(ref: ProviderRef) async throws -> T {
        try await _create(ref)
    }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        FutureProviderElement(provider: self, container: container)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }
    
    public static func == (lhs: FutureProvider, rhs: FutureProvider) -> Bool {
        lhs._id == rhs._id
    }
}
