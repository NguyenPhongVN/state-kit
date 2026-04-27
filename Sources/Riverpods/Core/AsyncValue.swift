import Foundation

/// Trạng thái của một Provider bất đồng bộ.
///
/// Tương đương với `AsyncValue` trong Riverpod của Flutter.
public enum AsyncValue<T: Sendable>: Sendable {
    case data(T)
    case error(Error)
    case loading
    
    /// Trạng thái đang làm mới dữ liệu (vừa có dữ liệu cũ, vừa đang load).
    case refreshing(T)
    
    public var value: T? {
        switch self {
        case .data(let t), .refreshing(let t): return t
        default: return nil
        }
    }
    
    public var isLoading: Bool {
        if case .loading = self { return true }
        if case .refreshing = self { return true }
        return false
    }
}
