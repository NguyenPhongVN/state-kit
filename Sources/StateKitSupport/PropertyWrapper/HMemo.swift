import Foundation

@propertyWrapper
@MainActor
public struct HMemo<Node> {

    private let _value: Node

    /// Khởi tạo với deps dạng mảng.
    /// Cú pháp dùng:
    /// ```
    /// @HMemo(deps: [a, b]) var result = expensive(a, b)
    /// ```
    public init(wrappedValue compute: @autoclosure @escaping () -> Node, deps: [AnyHashable]) {
        _value = useMemo({ compute() }, deps: deps)
    }

    /// Khởi tạo với deps variadic để viết gọn.
    /// Cú pháp dùng:
    /// ```
    /// @HMemo(a, b) var result = expensive(a, b)
    /// ```
    public init(wrappedValue compute: @autoclosure @escaping () -> Node, _ deps: AnyHashable...) {
        _value = useMemo({ compute() }, deps: deps)
    }

    /// Không có deps: chỉ tính một lần.
    /// Cú pháp dùng:
    /// ```
    /// @HMemo var formatter = DateFormatter()
    /// ```
    public init(wrappedValue compute: @autoclosure @escaping () -> Node) {
        _value = useMemo({ compute() })
    }

    public var wrappedValue: Node {
        _value
    }
}

