import Foundation
import StateKit

// MARK: - AsyncSequence Element

@MainActor
public final class AsyncSequenceProviderElement<T: Sendable, S: AsyncSequence>: ProviderElement<AsyncSequenceProvider<T, S>> where S.Element == T {
    private var task: Task<Void, Never>?
    
    public override func providerCreate() -> AsyncValue<T> {
        task?.cancel()
        
        task = Task { @MainActor in
            do {
                let sequence = provider.makeSequence(ref: self)
                for try await value in sequence {
                    if Task.isCancelled { return }
                    let oldState = self.stateBox?.value
                    self.stateBox?.value = .data(value)
                    self.notifyDependents()
                    self.container.notifyProviderUpdated(provider: self.provider, oldValue: oldState ?? .loading(), newValue: .data(value))
                }
            } catch {
                if Task.isCancelled { return }
                let oldState = self.stateBox?.value
                self.stateBox?.value = .error(error, previousData: oldState?.value)
                self.notifyDependents()
                self.container.notifyProviderUpdated(provider: self.provider, oldValue: oldState ?? .loading(), newValue: .error(error, previousData: oldState?.value))
            }
        }
        
        onDispose {
            self.task?.cancel()
        }
        
        if let lastValue = stateBox?.value.value {
            return .refreshing(lastValue)
        }
        return .loading()
    }
}

// MARK: - AsyncSequenceProvider

/// Một Provider cho các luồng dữ liệu liên tục dùng AsyncSequence.
public struct AsyncSequenceProvider<T: Sendable, S: AsyncSequence>: ProviderProtocol, @unchecked Sendable where S.Element == T {
    public typealias State = AsyncValue<T>
    
    private let _create: @MainActor (ProviderRef) -> S
    private let _id: AnyHashable
    public let autoDispose: Bool
    public let cacheTime: TimeInterval
    public let name: String?
    
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ create: @escaping @MainActor (ProviderRef) -> S
    ) {
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
        self._id = UUID()
    }
    
    @MainActor
    func makeSequence(ref: ProviderRef) -> S {
        _create(ref)
    }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        AsyncSequenceProviderElement(provider: self, container: container)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }
    
    public static func == (lhs: AsyncSequenceProvider, rhs: AsyncSequenceProvider) -> Bool {
        lhs._id == rhs._id
    }
}
