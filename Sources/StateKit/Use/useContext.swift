import Observation
import SwiftUI

/// A reference-type container for a value that can be shared across a view
/// hierarchy without passing it explicitly through every level.
///
/// `HookContext` is conceptually similar to React's Context API. A shared
/// instance is created at a high level in the tree and read inside any
/// descendant `StateScope` via `useContext(_:)`.
///
/// Because `HookContext` is a `final class`, passing it down the tree shares
/// the same instance — mutations to `value` are immediately visible to all
/// holders of the same reference.
///
/// ### Example
/// ```swift
/// let themeContext = HookContext(Theme.light)
///
/// struct RootView: StateView {
///     var stateBody: some View {
///         ChildView(context: themeContext)
///     }
/// }
///
/// struct ChildView: StateView {
///     let context: HookContext<Theme>
///     var stateBody: some View {
///         let theme = useContext(context)
///         Text("Theme: \(theme)")
///     }
/// }
/// ```
public final class HookContext<Value>: @unchecked Sendable {

    private var _value: Value
    private let _registrar = ObservationRegistrar()

    public var value: Value {
        get {
            _registrar.access(self, keyPath: \.value)
            return _value
        }
        set {
            _registrar.withMutation(of: self, keyPath: \.value) {
                _value = newValue
            }
        }
    }

    public init(_ value: Value) {
        _value = value
    }
}

extension HookContext: Observable {}

/// Returns the current value of the given `HookContext`.
///
/// `useContext` reads the shared reference passed down through the view tree
/// and returns its current `value`. The hook itself does not own any slot
/// state; it simply validates that a hook render is active, mirroring the
/// requirement that all hooks run inside `StateScope` / `StateView`.
///
/// Mutating `context.value` is visible to future renders that read the same
/// `HookContext` instance. Because `HookContext` is not `Observable`, those
/// mutations do not trigger a re-render by themselves; some other state
/// change must cause the scope to render again.
///
/// - Parameter context: The shared `HookContext` instance to read from.
/// - Returns: The `Value` stored in `context` at the time of the call.
@MainActor
public func useContext<T>(
    _ context: HookContext<T>
) -> T {
    guard StateRuntime.current != nil else {
        fatalError("\(#function) must be used inside StateRuntime")
    }
    return context.value
}
