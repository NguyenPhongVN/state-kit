import Foundation

/// Một Observer để theo dõi các sự kiện toàn cục trong ProviderContainer.
@MainActor
public protocol ProviderObserver: AnyObject {
    /// Gọi khi một Provider được khởi tạo lần đầu.
    func didAddProvider<P: ProviderProtocol>(_ provider: P, value: P.State, container: ProviderContainer)
    
    /// Gọi khi state của một Provider thay đổi.
    func didUpdateProvider<P: ProviderProtocol>(_ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer)
    
    /// Gọi khi một Provider bị hủy (dispose).
    func didDisposeProvider<P: ProviderProtocol>(_ provider: P, container: ProviderContainer)
}

/// Implement mặc định cho Observer (optional).
extension ProviderObserver {
    public func didAddProvider<P: ProviderProtocol>(_ provider: P, value: P.State, container: ProviderContainer) {}
    public func didUpdateProvider<P: ProviderProtocol>(_ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer) {}
    public func didDisposeProvider<P: ProviderProtocol>(_ provider: P, container: ProviderContainer) {}
}
