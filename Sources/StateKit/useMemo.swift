import Foundation
// MARK: - Internal storage for memoized values
final class _HookMemoBox<T> {
    var value: T
    var deps: [AnyHashable]?

    init(_ value: T, deps: [AnyHashable]?) {
        self.value = value
        self.deps = deps
    }
}

// MARK: - useMemo (React-like)

/// useMemo - ghi nhớ kết quả tính toán, chỉ tính lại khi `deps` thay đổi (giống React/React Native Hooks).
/// - Parameters:
///   - compute: Closure sinh ra giá trị cần ghi nhớ. Chỉ được gọi khi deps thay đổi (hoặc lần đầu).
///   - deps: Danh sách dependency Hashable để so sánh thay đổi.
/// - Returns: Giá trị đã memoized.
@MainActor
public func useMemo<T>(_ compute: () -> T, deps: [AnyHashable]) -> T {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside HookView")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        let value = compute()
        context.states.append(_HookMemoBox(value, deps: deps))
        return value
    } else {
        let box = context.states[index] as! _HookMemoBox<T>
        if box.deps != deps {
            box.value = compute()
            box.deps = deps
        }
        return box.value
    }
}

/// Tiện lợi: truyền deps dạng variadic.
/// Ví dụ: `let sum = useMemo({ a + b }, a, b)`
@MainActor
public func useMemo<T>(_ compute: () -> T, _ deps: AnyHashable...) -> T {
    useMemo(compute, deps: deps)
}

/// useMemo không có deps: chỉ tính một lần (tương đương deps rỗng trong React).
@MainActor
public func useMemo<T>(_ compute: () -> T) -> T {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside HookView")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        let value = compute()
        context.states.append(_HookMemoBox(value, deps: nil))
        return value
    } else {
        let box = context.states[index] as! _HookMemoBox<T>
        return box.value
    }
}

