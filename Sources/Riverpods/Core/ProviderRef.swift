import Foundation

/// Giao diện để tương tác với các Provider khác và quản lý vòng đời.
@MainActor
public protocol ProviderRef: AnyObject {
    /// Đọc một Provider và đăng ký dependency. Nếu Provider đó đổi, Provider hiện tại sẽ bị re-compute.
    func watch<P: ProviderProtocol>(_ provider: P) -> P.State
    
    /// Chỉ đọc giá trị hiện tại của Provider một lần, không tạo dependency.
    func read<P: ProviderProtocol>(_ provider: P) -> P.State
    
    /// Lắng nghe sự thay đổi của một Provider để thực hiện side-effects.
    func listen<P: ProviderProtocol>(
        _ provider: P,
        fireImmediately: Bool,
        listener: @escaping (P.State?, P.State) -> Void
    )
    
    /// Đăng ký hàm dọn dẹp khi Provider bị hủy hoặc re-compute.
    func onDispose(_ cleanup: @escaping () -> Void)
    
    /// Đăng ký hàm chạy khi không còn View nào watch Provider này nữa.
    func onCancel(_ callback: @escaping () -> Void)
    
    /// Đăng ký hàm chạy khi có View watch lại một Provider đang bị cancel.
    func onResume(_ callback: @escaping () -> Void)
    
    /// Đăng ký hàm chạy khi có listener đầu tiên được thêm vào.
    func onAddListener(_ callback: @escaping () -> Void)
    
    /// Đăng ký hàm chạy khi một listener bị xóa đi.
    func onRemoveListener(_ callback: @escaping () -> Void)
    
    /// Giữ cho Provider không bị dispose ngay cả khi không còn ai lắng nghe.
    @discardableResult
    func keepAlive() -> KeepAliveLink
    
    /// Ép buộc Provider hiện tại tính toán lại.
    func invalidate()
}

/// Một liên kết để kiểm soát việc giữ cho Provider sống.
public final class KeepAliveLink: Sendable {
    private let _onClose: @MainActor () -> Void
    
    init(onClose: @escaping @MainActor () -> Void) {
        self._onClose = onClose
    }
    
    @MainActor
    public func close() {
        _onClose()
    }
}
