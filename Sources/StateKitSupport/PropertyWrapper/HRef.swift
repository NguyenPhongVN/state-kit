import Foundation

@propertyWrapper
@MainActor public struct HRef<Node> {

    private let _ref: StateRef<Node>

    /// Khởi tạo với giá trị ban đầu (tính một lần), không gây re-render khi thay đổi.
    /// Ví dụ:
    /// ```swift
    /// @HRef var timer: Timer?
    /// ```
    public init(wrappedValue initial: @autoclosure @escaping () -> Node) {
        _ref = useRef(initial())
    }

    /// Biến thể khởi tạo bằng closure, hữu ích khi tính giá trị ban đầu tốn kém.
    public init(wrappedValue initial: @escaping () -> Node) {
        _ref = useRef(initial())
    }

    /// Truy cập/ghi trực tiếp giá trị của ref.
    /// Lưu ý: thay đổi giá trị không kích hoạt re-render (giống React `useRef`).
    public var wrappedValue: Node {
        get { _ref.value }
        nonmutating set { _ref.value = newValue }
    }

    /// Truy cập đối tượng `HookRef` bên dưới nếu cần truyền qua hàm/đối tượng khác.
    public var projectedValue: StateRef<Node> {
        _ref
    }
}

