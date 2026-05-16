import Foundation

/// Protocol cơ bản cho tất cả các loại Provider.
public protocol ProviderProtocol: Hashable, Sendable {
    associatedtype State
    
    /// Quyết định xem Provider có tự hủy khi không dùng hay không.
    var autoDispose: Bool { get }
    
    /// Thời gian chờ (giây) trước khi thực sự hủy provider sau khi không còn ai lắng nghe.
    var cacheTime: TimeInterval { get }
    
    /// Tên gợi nhớ của Provider để phục vụ việc Debug và Logging.
    var name: String? { get }
    
    @MainActor
    func createElement(container: ProviderContainer) -> AnyProviderElement
}

/// Một bản ghi để ghi đè giá trị hoặc logic của một Provider.
public struct ProviderOverride: @unchecked Sendable {
    let providerID: ProviderID
    let value: Any?
    let providerOverride: (any ProviderProtocol)?
}

extension ProviderProtocol {
    public var autoDispose: Bool { true }
    public var cacheTime: TimeInterval { 0 }
    public var name: String? { nil }
    
    /// Tạo một bản ghi ghi đè giá trị cho Provider này.
    public func overrideWith(_ value: State) -> ProviderOverride {
        ProviderOverride(providerID: ProviderID(self), value: value, providerOverride: nil)
    }
    
    /// Ghi đè Provider này bằng một logic của một Provider khác.
    public func overrideWithProvider<P: ProviderProtocol>(_ provider: P) -> ProviderOverride where P.State == State {
        ProviderOverride(providerID: ProviderID(self), value: nil, providerOverride: provider)
    }
    
    /// Chọn một phần của state để theo dõi. View sẽ chỉ re-render khi phần này thay đổi.
    public func select<Selected: Sendable & Hashable>(
        _ keyPath: KeyPath<State, Selected>
    ) -> SelectorProvider<Self, Selected> {
        SelectorProvider(provider: self, keyPath: keyPath)
    }
}

/// Một Provider trung gian để thực hiện việc 'select' state.
public struct SelectorProvider<P: ProviderProtocol, Selected: Sendable & Hashable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = Selected
    
    public let provider: P
    public let keyPath: KeyPath<P.State, Selected>
    
    public var autoDispose: Bool { provider.autoDispose }
    
    public init(provider: P, keyPath: KeyPath<P.State, Selected>) {
        self.provider = provider
        self.keyPath = keyPath
    }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        SelectorProviderElement(provider: self, container: container)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
        hasher.combine(keyPath)
    }
    
    public static func == (lhs: SelectorProvider, rhs: SelectorProvider) -> Bool {
        lhs.provider == rhs.provider && lhs.keyPath == rhs.keyPath
    }
}

@MainActor
public final class SelectorProviderElement<P: ProviderProtocol, Selected: Sendable & Hashable>: ProviderElement<SelectorProvider<P, Selected>> {
    private var _lastValue: Selected?
    
    public override func providerCreate() -> Selected {
        let state = watch(provider.provider)
        let newValue = state[keyPath: provider.keyPath]
        _lastValue = newValue
        return newValue
    }
    
    public override func performUpdate() {
        let state = read(provider.provider)
        let newValue = state[keyPath: provider.keyPath]
        
        if newValue != _lastValue {
            _lastValue = newValue
            stateBox?.value = newValue
            notifyDependents()
        }
    }
}
