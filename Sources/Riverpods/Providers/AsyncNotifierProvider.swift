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
    
    public var state: AsyncValue<State> {
        get { _state! }
        set {
            _state = newValue
            onUpdate?()
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
        
        // Nếu đã có dữ liệu, chuyển sang trạng thái refreshing
        if let current = _state?.value {
            _state = .refreshing(current)
        } else {
            _state = .loading
        }
        onUpdate?()
        
        task = Task { @MainActor in
            do {
                let newValue = try await build()
                if Task.isCancelled { return }
                _state = .data(newValue)
                onUpdate?()
            } catch {
                if Task.isCancelled { return }
                _state = .error(error)
                onUpdate?()
            }
        }
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
    
    public init(autoDispose: Bool = true, _ create: @escaping @MainActor () -> N) {
        self.autoDispose = autoDispose
        self._create = create
        self._id = UUID()
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
