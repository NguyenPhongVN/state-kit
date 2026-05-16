import Foundation
import Observation

/// Nơi lưu trữ và quản lý tất cả các Provider trong ứng dụng.
@MainActor
@Observable
public final class ProviderContainer {
    
    public static let shared = ProviderContainer()
    
    private var elements: [ProviderID: any AnyProviderElement] = [:]
    private let overrides: [ProviderID: ProviderOverride]
    
    /// Container cha (nếu có).
    public let parent: ProviderContainer?
    
    /// Danh sách các observer để theo dõi sự kiện.
    @ObservationIgnored
    private var observers: [ProviderObserver] = []
    
    // MARK: - Batching
    
    @ObservationIgnored
    private var isBatching = false
    
    @ObservationIgnored
    private var pendingChanges = Set<ProviderID>()
    
    // MARK: - Cycle Detection
    
    @ObservationIgnored
    var recomputePath = [ProviderID]()
    
    public init(
        parent: ProviderContainer? = nil,
        overrides: [ProviderOverride] = [],
        observers: [ProviderObserver] = []
    ) {
        self.parent = parent
        var map = [ProviderID: ProviderOverride]()
        for o in overrides {
            map[o.providerID] = o
        }
        self.overrides = map
        self.observers = observers
    }
    
    /// Thêm một observer mới.
    public func addObserver(_ observer: ProviderObserver) {
        observers.append(observer)
    }

    /// Trả về element cho một Provider, tạo mới nếu chưa có.
    public func ensureElement<P: ProviderProtocol>(for provider: P) -> AnyProviderElement {
        let id = ProviderID(provider)
        
        // 1. Kiểm tra xem có element hiện tại không
        if let element = elements[id] {
            return element
        }
        
        // 2. Nếu không có override ở đây, nhưng có container cha, hãy thử tìm ở cha
        if overrides[id] == nil, let parent = parent {
            return parent.ensureElement(for: provider)
        }
        
        // 3. Xử lý logic override
        if let overrideRecord = overrides[id], let customProvider = overrideRecord.providerOverride {
            // Nếu override bằng một provider khác, ta tạo element từ provider đó nhưng gán ID của provider gốc
            let element = customProvider.createElement(container: self)
            elements[id] = element
            
            // Notify observers
            let value = (element as! ProviderElement<P>).getState()
            for observer in observers {
                observer.didAddProvider(provider, value: value, container: self)
            }
            return element
        }
        
        // 4. Tạo mới element ở container này
        let element = provider.createElement(container: self)
        elements[id] = element
        
        // Kiểm tra xem có bị ghi đè (override) giá trị không
        if let overrideRecord = overrides[id], let value = overrideRecord.value, let stateElement = element as? ProviderElement<P> {
            stateElement.stateBox = StateBox(value as! P.State)
        }
        
        // Notify observers
        let value = (element as! ProviderElement<P>).getState()
        for observer in observers {
            observer.didAddProvider(provider, value: value, container: self)
        }
        
        return element
    }

    /// Làm mới một Provider bằng cách ép buộc tính toán lại và trả về kết quả.
    @discardableResult
    public func refresh<P: ProviderProtocol>(_ provider: P) -> P.State {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        return element.recompute()
    }
    
    /// Đọc giá trị hiện tại của một Provider.
    public func read<P: ProviderProtocol>(_ provider: P) -> P.State {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        return element.getState()
    }
    
    /// Watch một provider từ bên ngoài (thường là từ View).
    public func watch<P: ProviderProtocol>(_ provider: P) -> P.State {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        return element.getState()
    }

    /// Lắng nghe thay đổi của một Provider từ bên ngoài SwiftUI.
    public func listen<P: ProviderProtocol>(
        _ provider: P,
        fireImmediately: Bool = false,
        listener: @escaping (P.State?, P.State) -> Void
    ) -> ProviderSubscription {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        return element.addListener(fireImmediately: fireImmediately, listener: listener)
    }
    
    /// Đăng ký listener cho một Provider (dùng cho SwiftUI Watch).
    public func addListener<P: ProviderProtocol>(for provider: P) -> P.State {
        let element = ensureElement(for: provider) as! ProviderElement<P>
        element.incrementListeners()
        return element.getState()
    }
    
    public func removeListener<P: ProviderProtocol>(for provider: P) {
        let id = ProviderID(provider)
        guard let element = elements[id] else { return }
        element.decrementListeners()
        
        // Nếu có cacheTime, ta không check dispose ngay ở đây mà đợi element tự trigger
        if provider.cacheTime <= 0 {
            checkAutoDispose(id: id, element: element, provider: provider)
        }
    }

    func checkAutoDispose<P: ProviderProtocol>(id: ProviderID, element: any AnyProviderElement, provider: P) {
        if element.listenersCount <= 0 && provider.autoDispose && !element.isKeepAlive {
            if element.dependents.isEmpty {
                // Notify observers before disposal
                for observer in observers {
                    observer.didDisposeProvider(provider, container: self)
                }
                
                element.dispose()
                elements.removeValue(forKey: id)
            }
        }
    }
    
    func element(for id: ProviderID) -> (any AnyProviderElement)? {
        return elements[id]
    }
    
    // MARK: - Internal Propagation
    
    /// Được gọi bởi ProviderElement khi nó bị invalidate.
    func notifyProviderChanged(id: ProviderID) {
        pendingChanges.insert(id)
        if isBatching { return }
        flushChanges()
    }

    func notifyProviderUpdated<P: ProviderProtocol>(provider: P, oldValue: P.State, newValue: P.State) {
        for observer in observers {
            observer.didUpdateProvider(provider, oldValue: oldValue, newValue: newValue, container: self)
        }
    }
    
    /// Gom nhiều thay đổi và xử lý một lượt.
    public func batch(_ body: () -> Void) {
        let alreadyBatching = isBatching
        isBatching = true
        body()
        isBatching = alreadyBatching
        
        if !isBatching {
            flushChanges()
        }
    }
    
    private func flushChanges() {
        if pendingChanges.isEmpty { return }
        
        isBatching = true
        defer { isBatching = false }
        
        while !pendingChanges.isEmpty {
            let changes = pendingChanges
            pendingChanges.removeAll()
            
            for id in changes {
                if let element = elements[id] {
                    element.performUpdate()
                }
            }
        }
    }
}

/// Một token đại diện cho một đăng ký lắng nghe Provider.
public final class ProviderSubscription: Sendable {
    private let _onClose: @MainActor () -> Void
    
    init(onClose: @escaping @MainActor () -> Void) {
        self._onClose = onClose
    }
    
    @MainActor
    public func close() {
        _onClose()
    }
    
    deinit {
        let close = _onClose
        Task { @MainActor in
            close()
        }
    }
}
