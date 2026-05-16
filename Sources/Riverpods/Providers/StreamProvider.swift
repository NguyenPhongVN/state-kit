import Foundation
import StateKit
import Combine

// MARK: - Stream Element

@MainActor
public final class StreamProviderElement<T: Sendable>: ProviderElement<StreamProvider<T>> {
    public override func providerCreate() -> AsyncValue<T> {
        let cancellable = provider.stream(ref: self)
            .sink { completion in
                Task { @MainActor in
                    switch completion {
                    case .finished:
                        break 
                    case .failure(let error):
                        let oldState = self.stateBox?.value
                        self.stateBox?.value = .error(error, previousData: oldState?.value)
                        self.notifyDependents()
                        self.container.notifyProviderUpdated(provider: self.provider, oldValue: oldState ?? .loading(), newValue: .error(error, previousData: oldState?.value))
                    }
                }
            } receiveValue: { value in
                Task { @MainActor in
                    let oldState = self.stateBox?.value
                    self.stateBox?.value = .data(value)
                    self.notifyDependents()
                    self.container.notifyProviderUpdated(provider: self.provider, oldValue: oldState ?? .loading(), newValue: .data(value))
                }
            }
        
        onDispose {
            cancellable.cancel()
        }
        
        if let lastValue = stateBox?.value.value {
            return .refreshing(lastValue)
        }
        return .loading()
    }
}

// MARK: - StreamProvider

/// Một Provider cho các luồng dữ liệu liên tục (Combine Publisher).
public struct StreamProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = AsyncValue<T>
    
    private let _create: @MainActor (ProviderRef) -> AnyPublisher<T, Error>
    private let _id: AnyHashable
    public let autoDispose: Bool
    public let cacheTime: TimeInterval
    public let name: String?
    
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ create: @escaping @MainActor (ProviderRef) -> AnyPublisher<T, Error>
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
        create: @escaping @MainActor (ProviderRef) -> AnyPublisher<T, Error>
    ) {
        self._id = id
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
    }
    
    @MainActor
    func stream(ref: ProviderRef) -> AnyPublisher<T, Error> {
        _create(ref)
    }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        StreamProviderElement(provider: self, container: container)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }
    
    public static func == (lhs: StreamProvider, rhs: StreamProvider) -> Bool {
        lhs._id == rhs._id
    }
}
