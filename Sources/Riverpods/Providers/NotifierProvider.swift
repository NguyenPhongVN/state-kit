import Foundation
import Observation

// MARK: - Notifier

/// Một class cơ bản để quản lý state phức tạp.
@MainActor
@Observable
open class Notifier<State: Sendable> {
    public internal(set) var ref: ProviderRef!
    
    @ObservationIgnored
    private var _state: State?
    
    @ObservationIgnored
    private var onUpdate: (() -> Void)?
    
    public var state: State {
        get { _state! }
        set {
            _state = newValue
            onUpdate?()
        }
    }
    
    public init() {}
    
    /// Khởi tạo state ban đầu. Được gọi khi provider khởi tạo HOẶC khi dependency thay đổi.
    open func build() -> State {
        fatalError("Phải override hàm build()")
    }
    
    internal func _setup(ref: ProviderRef, onUpdate: @escaping () -> Void) {
        self.ref = ref
        self.onUpdate = onUpdate
    }
    
    @discardableResult
    internal func _recompute() -> State {
        let newState = build()
        self._state = newState
        return newState
    }
    
    /// Cập nhật state hiện tại bằng một closure.
    public func update(_ transform: (State) -> State) {
        state = transform(state)
    }
}

// MARK: - Notifier Element

@MainActor
public final class NotifierProviderElement<N: Notifier<T>, T: Sendable>: ProviderElement<NotifierProvider<N, T>> {
    public var notifier: N?
    
    public override func providerCreate() -> T {
        if let n = notifier {
            // Recompute logic when dependencies change
            return n._recompute()
        }
        
        // Initial setup
        let n = provider.createNotifier()
        notifier = n
        n._setup(ref: self) { [weak self] in
            // Khi người dùng gán notifier.state = ...
            if let self, let newState = self.notifier?.state {
                self.stateBox?.value = newState
                self.notifyDependents()
            }
        }
        return n._recompute()
    }
    
    public override func dispose() {
        super.dispose()
        notifier = nil
    }
}

@MainActor
public final class NotifierInstanceElement<N: Notifier<T>, T: Sendable>: ProviderElement<NotifierInstanceProvider<N, T>> {
    public override func providerCreate() -> N {
        let parentElement = container.ensureElement(for: provider.provider) as! NotifierProviderElement<N, T>
        // Ensure the notifier and its state exist
        _ = parentElement.getState()
        return parentElement.notifier!
    }
}

// MARK: - NotifierProvider

/// Provider dùng để sử dụng một Notifier.
public struct NotifierProvider<N: Notifier<T>, T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = T
    
    private let _create: @MainActor () -> N
    private let _id: AnyHashable
    public let autoDispose: Bool
    public let cacheTime: TimeInterval
    public let name: String?
    
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ create: @escaping @MainActor () -> N
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
        create: @escaping @MainActor () -> N
    ) {
        self._id = id
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
    }
    
    @MainActor
    func createNotifier() -> N {
        _create()
    }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        NotifierProviderElement(provider: self, container: container)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }
    
    public static func == (lhs: NotifierProvider, rhs: NotifierProvider) -> Bool {
        lhs._id == rhs._id
    }
    
    public var notifier: NotifierInstanceProvider<N, T> {
        NotifierInstanceProvider(provider: self)
    }
}

/// Provider để lấy instance của Notifier (thay vì chỉ lấy state).
public struct NotifierInstanceProvider<N: Notifier<T>, T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = N
    let provider: NotifierProvider<N, T>
    public var autoDispose: Bool { provider.autoDispose }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        NotifierInstanceElement(provider: self, container: container)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
        hasher.combine("instance")
    }
    
    public static func == (lhs: NotifierInstanceProvider, rhs: NotifierInstanceProvider) -> Bool {
        lhs.provider == rhs.provider
    }
}
