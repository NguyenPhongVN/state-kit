import Foundation
import Observation

// MARK: - StateProvider Element

@MainActor
public final class StateProviderElement<T: Sendable>: ProviderElement<StateProvider<T>> {
    private var _currentValue: T?
    
    public override func providerCreate() -> T {
        if let value = _currentValue {
            return value
        }
        let initial = provider.defaultValue(ref: self)
        _currentValue = initial
        return initial
    }
    
    public func updateState(_ newValue: T) {
        _currentValue = newValue
        invalidate()
    }
}

// MARK: - StateProvider

/// Một Provider cung cấp một giá trị có thể thay đổi trực tiếp.
public struct StateProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = T
    
    private let _defaultValue: @MainActor (ProviderRef) -> T
    private let _id: AnyHashable
    public let autoDispose: Bool
    public let cacheTime: TimeInterval
    public let name: String?
    
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ defaultValue: @escaping @MainActor (ProviderRef) -> T
    ) {
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._defaultValue = defaultValue
        self._id = UUID()
    }
    
    internal init(
        id: AnyHashable,
        autoDispose: Bool,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        defaultValue: @escaping @MainActor (ProviderRef) -> T
    ) {
        self._id = id
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._defaultValue = defaultValue
    }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        StateProviderElement(provider: self, container: container)
    }
    
    @MainActor
    func defaultValue(ref: ProviderRef) -> T {
        _defaultValue(ref)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }
    
    public static func == (lhs: StateProvider, rhs: StateProvider) -> Bool {
        lhs._id == rhs._id
    }
    
    /// Trả về một "notifier" để thay đổi giá trị của StateProvider.
    public var notifier: StateProviderNotifier<T> {
        StateProviderNotifier(provider: self)
    }
}

/// Đối tượng cho phép thay đổi state của một StateProvider.
public struct StateProviderNotifier<T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = StateController<T>
    
    let provider: StateProvider<T>
    public var autoDispose: Bool { provider.autoDispose }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        SimpleProviderElement(provider: self, container: container) { ref in
            let element = container.ensureElement(for: provider) as! StateProviderElement<T>
            let initialState = element.getState()
            
            return StateController(initialState) { newValue in
                element.updateState(newValue)
            }
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
        hasher.combine("notifier")
    }
    
    public static func == (lhs: StateProviderNotifier, rhs: StateProviderNotifier) -> Bool {
        lhs.provider == rhs.provider
    }
}

/// Quản lý giá trị của StateProvider.
@MainActor
public final class StateController<T: Sendable>: Observable {
    private var _state: T
    private let onUpdate: (T) -> Void
    
    public var state: T {
        get { _state }
        set {
            _state = newValue
            onUpdate(newValue)
        }
    }
    
    init(_ initialState: T, onUpdate: @escaping (T) -> Void) {
        self._state = initialState
        self.onUpdate = onUpdate
    }
}
