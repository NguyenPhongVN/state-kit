import Foundation

/// Trạng thái của một Provider bất đồng bộ.
///
/// Tương đương với `AsyncValue` trong Riverpod của Flutter.
public enum AsyncValue<T: Sendable>: Sendable {
    case data(T)
    case error(Error, previousData: T? = nil)
    case loading(previousData: T? = nil)
    
    /// Trạng thái đang làm mới dữ liệu (vừa có dữ liệu cũ, vừa đang load).
    case refreshing(T)
    
    public var value: T? {
        switch self {
        case .data(let t), .refreshing(let t): return t
        case .loading(let prev): return prev
        case .error(_, let prev): return prev
        }
    }
    
    public var error: Error? {
        if case .error(let e, _) = self { return e }
        return nil
    }

    public var isLoading: Bool {
        switch self {
        case .loading, .refreshing: return true
        default: return false
        }
    }
    
    public var isRefreshing: Bool {
        if case .refreshing = self { return true }
        return false
    }

    public var hasValue: Bool {
        value != nil
    }

    // MARK: - Pattern Matching APIs

    /// Chuyển đổi trạng thái sang một giá trị khác dựa trên case hiện tại.
    public func when<Result>(
        data: (T) -> Result,
        error: (Error, T?) -> Result,
        loading: (T?) -> Result
    ) -> Result {
        switch self {
        case .data(let value):
            return data(value)
        case .refreshing(let value):
            return data(value)
        case .error(let err, let prev):
            return error(err, prev)
        case .loading(let prev):
            return loading(prev)
        }
    }
    
    /// Biến đổi dữ liệu bên trong nếu đang ở case .data hoặc .refreshing.
    public func map<U>(_ transform: (T) -> U) -> AsyncValue<U> {
        switch self {
        case .data(let value):
            return .data(transform(value))
        case .refreshing(let value):
            return .refreshing(transform(value))
        case .error(let error, let prev):
            return .error(error, previousData: prev.map(transform))
        case .loading(let prev):
            return .loading(previousData: prev.map(transform))
        }
    }
    
    /// Chạy một block code ném lỗi và tự động chuyển đổi kết quả sang AsyncValue.
    public static func `guard`(_ action: @escaping () async throws -> T) async -> AsyncValue<T> {
        do {
            return .data(try await action())
        } catch {
            return .error(error)
        }
    }
    
    /// Trả về giá trị nếu có, nếu không sẽ throw lỗi (nếu có) hoặc FatalError.
    public func unwrap() throws -> T {
        switch self {
        case .data(let val), .refreshing(let val):
            return val
        case .error(let err, _):
            throw err
        case .loading(let prev):
            if let prev = prev { return prev }
            fatalError("Cố gắng unwrap một AsyncValue đang loading mà không có dữ liệu cũ.")
        }
    }
    
    /// Cập nhật giá trị hiện tại bằng một closure.
    public func update(_ transform: (T) -> T) -> AsyncValue<T> {
        if let val = value {
            let newVal = transform(val)
            switch self {
            case .data: return .data(newVal)
            case .refreshing: return .refreshing(newVal)
            case .error(let err, _): return .error(err, previousData: newVal)
            case .loading: return .loading(previousData: newVal)
            }
        }
        return self
    }
}
