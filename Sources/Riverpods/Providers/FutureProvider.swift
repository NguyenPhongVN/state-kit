import Foundation
import StateKit
import Observation

// MARK: - Future Element

@MainActor
public final class FutureProviderElement<T: Sendable>: ProviderElement<FutureProvider<T>> {
    private var continuations: [CheckedContinuation<T, Error>] = []
    
    public override func providerCreate() -> AsyncValue<T> {
        let task = Task { @MainActor in
            do {
                let value = try await provider.fetch(ref: self)
                if Task.isCancelled { return }
                let newState: AsyncValue<T> = .data(value)
                let oldState = self.stateBox?.value
                self.stateBox?.value = newState
                
                // Resolve continuations
                let conts = self.continuations
                self.continuations.removeAll()
                conts.forEach { $0.resume(returning: value) }
                
                self.notifyDependents()
                self.container.notifyProviderUpdated(provider: self.provider, oldValue: oldState ?? .loading(), newValue: newState)
            } catch {
                if Task.isCancelled { return }
                let actualOldState = self.stateBox?.value
                let newState: AsyncValue<T> = .error(error, previousData: actualOldState?.value)
                self.stateBox?.value = newState
                
                // Resolve continuations
                let conts = self.continuations
                self.continuations.removeAll()
                conts.forEach { $0.resume(throwing: error) }
                
                self.notifyDependents()
                self.container.notifyProviderUpdated(provider: self.provider, oldValue: actualOldState ?? .loading(), newValue: newState)
            }
                }

        
        onDispose {
            task.cancel()
            self.continuations.forEach { $0.resume(throwing: CancellationError()) }
            self.continuations.removeAll()
        }
        
        if let lastValue = stateBox?.value.value {
            return .refreshing(lastValue)
        }
        return .loading()
    }
    
    func getFuture() async throws -> T {
        if let value = getState().value {
            return value
        }
        if case .error(let err, _) = getState() {
            throw err
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }
}

// MARK: - FutureProvider

/// Một Provider cho các tác vụ bất đồng bộ một lần.
public struct FutureProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = AsyncValue<T>
    
    private let _create: @MainActor (ProviderRef) async throws -> T
    private let _id: AnyHashable
    public let autoDispose: Bool
    public let cacheTime: TimeInterval
    public let name: String?
    
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ create: @escaping @MainActor (ProviderRef) async throws -> T
    ) {
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
        self._id = UUID()
    }
    
    internal init(
        id: AnyHashable,
        autoDispose: Bool,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        create: @escaping @MainActor (ProviderRef) async throws -> T
    ) {
        self._id = id
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
    }
    
    /// Truy cập giá trị dưới dạng Future (awaitable).
    public var future: FutureFutureProvider<T> {
        FutureFutureProvider(provider: self)
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

/// Provider phụ trợ để await FutureProvider.
public struct FutureFutureProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = Task<T, Error>
    public let provider: FutureProvider<T>
    public var autoDispose: Bool { provider.autoDispose }
    
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        FutureFutureElement(provider: self, container: container)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
    }
    
    public static func == (lhs: FutureFutureProvider, rhs: FutureFutureProvider) -> Bool {
        lhs.provider == rhs.provider
    }
}

@MainActor
final class FutureFutureElement<T: Sendable>: ProviderElement<FutureFutureProvider<T>> {
    override func providerCreate() -> Task<T, Error> {
        let parentElement = container.ensureElement(for: provider.provider) as! FutureProviderElement<T>
        _ = parentElement.getState()
        
        return Task { @MainActor in
            try await parentElement.getFuture()
        }
    }
}
