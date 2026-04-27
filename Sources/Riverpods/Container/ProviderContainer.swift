import Foundation
import Observation

/// Nơi lưu trữ và quản lý tất cả các Provider trong ứng dụng.
@MainActor
@Observable
public final class ProviderContainer {
    
    public static let shared = ProviderContainer()
    
    private var elements: [ProviderID: any AnyProviderElement] = [:]
    private let overrides: [ProviderID: ProviderOverride]
    
    // MARK: - Batching
    
    @ObservationIgnored
    private var isBatching = false
    
    @ObservationIgnored
    private var pendingChanges = Set<ProviderID>()
    
    // MARK: - Cycle Detection
    
    @ObservationIgnored
    var recomputePath = [ProviderID]()
    
    public init(overrides: [ProviderOverride] = []) {
        var map = [ProviderID: ProviderOverride]()
        for o in overrides {
            map[o.providerID] = o
        }
        self.overrides = map
    }
    
    /// Trả về element cho một Provider, tạo mới nếu chưa có.
    public func ensureElement<P: ProviderProtocol>(for provider: P) -> AnyProviderElement {
        let id = ProviderID(provider)
        if let element = elements[id] {
            return element
        }
        
        let element = provider.createElement(container: self)
        elements[id] = element
        
        // Kiểm tra xem có bị ghi đè (override) không
        if let overrideRecord = overrides[id], let stateElement = element as? ProviderElement<P> {
            stateElement.stateBox = StateBox(overrideRecord.value as! P.State)
        }
        
        return element
    }

    /// Làm mới một Provider bằng cách ép buộc tính toán lại.
    public func refresh<P: ProviderProtocol>(_ provider: P) {
        ensureElement(for: provider).invalidate()
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
        
        if element.listenersCount <= 0 && provider.autoDispose {
            if element.dependents.isEmpty {
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
