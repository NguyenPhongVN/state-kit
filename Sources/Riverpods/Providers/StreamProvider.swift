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
                        self.stateBox?.value = .error(error)
                        self.notifyDependents()
                    }
                }
            } receiveValue: { value in
                Task { @MainActor in
                    self.stateBox?.value = .data(value)
                    self.notifyDependents()
                }
            }
        
        onDispose {
            cancellable.cancel()
        }
        
        if let lastValue = stateBox?.value.value {
            return .refreshing(lastValue)
        }
        return .loading
    }
}

// MARK: - StreamProvider

/// Một Provider cho các luồng dữ liệu liên tục (Combine Publisher).
public struct StreamProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = AsyncValue<T>
    
    private let _create: @MainActor (ProviderRef) -> AnyPublisher<T, Error>
    private let _id: AnyHashable
    public let autoDispose: Bool
    
    public init(autoDispose: Bool = true, _ create: @escaping @MainActor (ProviderRef) -> AnyPublisher<T, Error>) {
        self.autoDispose = autoDispose
        self._create = create
        self._id = UUID()
    }
    
    internal init(id: AnyHashable, autoDispose: Bool, create: @escaping @MainActor (ProviderRef) -> AnyPublisher<T, Error>) {
        self._id = id
        self.autoDispose = autoDispose
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
