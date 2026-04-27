import Foundation

// MARK: - Generic Element for simple providers

@MainActor
public final class SimpleProviderElement<P: ProviderProtocol>: ProviderElement<P> {
    private let _create: (ProviderRef) -> P.State
    
    public init(provider: P, container: ProviderContainer, create: @escaping (ProviderRef) -> P.State) {
        self._create = create
        super.init(provider: provider, container: container)
    }
    
    public override func providerCreate() -> P.State {
        return _create(self)
    }
}

// MARK: - Provider

/// Một Provider cung cấp giá trị read-only, thường dùng cho các giá trị tính toán (selectors).
public struct Provider<T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = T
    
    private let _create: @MainActor (ProviderRef) -> T
    private let _id: AnyHashable
    public let autoDispose: Bool
    
    public init(autoDispose: Bool = true, _ create: @escaping @MainActor (ProviderRef) -> T) {
        self.autoDispose = autoDispose
        self._create = create
        self._id = UUID()
    }
    
    internal init(id: AnyHashable, autoDispose: Bool, create: @escaping @MainActor (ProviderRef) -> T) {
        self._id = id
        self.autoDispose = autoDispose
        self._create = create
    }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        SimpleProviderElement(provider: self, container: container, create: _create)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }
    
    public static func == (lhs: Provider, rhs: Provider) -> Bool {
        lhs._id == rhs._id
    }
}
