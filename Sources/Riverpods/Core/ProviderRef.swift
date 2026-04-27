import Foundation

/// Giao diện để tương tác với các Provider khác và quản lý vòng đời.
@MainActor
public protocol ProviderRef: AnyObject {
    /// Đọc một Provider và đăng ký dependency. Nếu Provider đó đổi, Provider hiện tại sẽ bị re-compute.
    func watch<P: ProviderProtocol>(_ provider: P) -> P.State
    
    /// Chỉ đọc giá trị hiện tại của Provider một lần, không tạo dependency.
    func read<P: ProviderProtocol>(_ provider: P) -> P.State
    
    /// Đăng ký hàm dọn dẹp khi Provider bị hủy hoặc re-compute.
    func onDispose(_ cleanup: @escaping () -> Void)
    
    /// Đăng ký hàm chạy khi không còn View nào watch Provider này nữa.
    func onCancel(_ callback: @escaping () -> Void)
    
    /// Đăng ký hàm chạy khi có View watch lại một Provider đang bị cancel.
    func onResume(_ callback: @escaping () -> Void)
    
    /// Ép buộc Provider hiện tại tính toán lại.
    func invalidate()
}
