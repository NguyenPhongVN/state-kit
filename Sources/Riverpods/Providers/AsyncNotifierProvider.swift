import Foundation
import Observation

// MARK: - AsyncNotifier

/// Một class quản lý trạng thái bất đồng bộ phức tạp.
///
/// Tương đương với `AsyncNotifier` trong Riverpod của Flutter.
@MainActor
@Observable
open class AsyncNotifier<State: Sendable> {
    public internal(set) var ref: ProviderRef!
    
    @ObservationIgnored
    private var _state: AsyncValue<State>?
    
    @ObservationIgnored
    private var onUpdate: (() -> Void)?
    
    @ObservationIgnored
    private var task: Task<Void, Never>?
    
    @ObservationIgnored
    private var _futureContinuation: [CheckedContinuation<State, Error>] = []
    
    public var state: AsyncValue<State> {
        get { _state! }
        set {
            _state = newValue
            onUpdate?()
            
            // Resolve future if data or error
            switch newValue {
            case .data(let val):
                let continuations = _futureContinuation
                _futureContinuation.removeAll()
                continuations.forEach { $0.resume(returning: val) }
            case .error(let err, _):
                let continuations = _futureContinuation
                _futureContinuation.removeAll()
                continuations.forEach { $0.resume(throwing: err) }
            default:
                break
            }
        }
    }
    
    public var future: State {
        get async throws {
            if let _state = _state {
                switch _state {
                case .data(let val): return val
                case .error(let err, _): throw err
                default: break
                }
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                _futureContinuation.append(continuation)
            }
        }
    }
    
    public init() {}
    
    /// Khởi tạo state ban đầu một cách bất đồng bộ.
    open func build() async throws -> State {
        fatalError("Phải override hàm build()")
    }
    
    internal func _setup(ref: ProviderRef, onUpdate: @escaping () -> Void) {
        self.ref = ref
        self.onUpdate = onUpdate
    }
    
    internal func _recompute() {
        task?.cancel()
        
        let previousData = _state?.value
        
        // Nếu đã có dữ liệu, chuyển sang trạng thái refreshing
        if let current = previousData {
            _state = .refreshing(current)
        } else {
            _state = .loading()
        }
        onUpdate?()
        
        task = Task { @MainActor in
            do {
                let newValue = try await build()
                if Task.isCancelled { return }
                state = .data(newValue)
            } catch {
                if Task.isCancelled { return }
                state = .error(error, previousData: previousData)
            }
        }
    }
    
    /// Cập nhật data bên trong AsyncValue bằng một closure.
    public func update(_ transform: (State) -> State) {
        state = state.update(transform)
    }
}

// MARK: - AsyncNotifier Element

@MainActor
public final class AsyncNotifierProviderElement<N: AsyncNotifier<T>, T: Sendable>: ProviderElement<AsyncNotifierProvider<N, T>> {
    public var notifier: N?
    
    public override func providerCreate() -> AsyncValue<T> {
        if let n = notifier {
            n._recompute()
            return n.state
        }
        
        let n = provider.createNotifier()
        notifier = n
        n._setup(ref: self) { [weak self] in
            if let self, let newState = self.notifier?.state {
                self.stateBox?.value = newState
                self.notifyDependents()
            }
        }
        n._recompute()
        return n.state
    }
    
    public override func dispose() {
        super.dispose()
        notifier = nil
    }
}

// MARK: - AsyncNotifierProvider

/// Provider dùng để sử dụng một AsyncNotifier.
public struct AsyncNotifierProvider<N: AsyncNotifier<T>, T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = AsyncValue<T>
    
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
    
    /// Truy cập future của notifier.
    public var future: AsyncNotifierFutureProvider<N, T> {
        AsyncNotifierFutureProvider(provider: self)
    }
    
    @MainActor
    func createNotifier() -> N {
        _create()
    }
    
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        AsyncNotifierProviderElement(provider: self, container: container)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }
    
    public static func == (lhs: AsyncNotifierProvider, rhs: AsyncNotifierProvider) -> Bool {
        lhs._id == rhs._id
    }
}

/// Một Provider phụ trợ để await giá trị từ AsyncNotifier.
public struct AsyncNotifierFutureProvider<N: AsyncNotifier<T>, T: Sendable>: ProviderProtocol, @unchecked Sendable {
    public typealias State = Task<T, Error>
    public let provider: AsyncNotifierProvider<N, T>
    public var autoDispose: Bool { provider.autoDispose }
    
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        AsyncNotifierFutureElement(provider: self, container: container)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
    }
    
    public static func == (lhs: AsyncNotifierFutureProvider, rhs: AsyncNotifierFutureProvider) -> Bool {
        lhs.provider == rhs.provider
    }
}

@MainActor
final class AsyncNotifierFutureElement<N: AsyncNotifier<T>, T: Sendable>: ProviderElement<AsyncNotifierFutureProvider<N, T>> {
    override func providerCreate() -> Task<T, Error> {
        let parentElement = container.ensureElement(for: provider.provider) as! AsyncNotifierProviderElement<N, T>
        _ = parentElement.getState()
        
        return Task { @MainActor in
            try await parentElement.notifier!.future
        }
    }
}
