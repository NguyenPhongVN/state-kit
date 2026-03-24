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
public final class HookContext<Value> {

    public var value: Value

    public init(_ value: Value) {
        self.value = value
    }
}

/// Returns the current value of the given `HookContext`.
///
/// - Warning: This function is not yet implemented. Calling it always results
///   in a `fatalError` at runtime regardless of whether `StateRuntime.current`
///   is set.
///
/// - Parameter context: The shared `HookContext` instance to read from.
/// - Returns: The `Value` stored in `context` at the time of the call.
func useContext<T>(
    _ context: HookContext<T>
) -> T {
    fatalError("Hooks must be used inside StateRuntime")
}

/// Reads a value from the SwiftUI `EnvironmentValues` of the enclosing
/// `StateScope`.
///
/// Searches `StateRuntime.current.states` for an `EnvironmentValues` instance
/// injected by the surrounding `StateScope` and reads the value at `keyPath`.
/// Falls back to a default `EnvironmentValues()` if none is found.
///
/// Unlike regular hook slots, this function does not consume a position via
/// `context.nextIndex()` — it scans the full `states` array for the first
/// `EnvironmentValues` object, so it is order-independent relative to other
/// hook calls.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`.
///
/// - Parameter keyPath: A key path into `EnvironmentValues` identifying the
///   value to read (e.g. `\.colorScheme`, `\.locale`).
/// - Returns: The value at `keyPath` from the injected `EnvironmentValues`,
///   or the SwiftUI default for that key if no environment has been injected.
///
/// ### Example
/// ```swift
/// struct ThemedView: StateView {
///     var stateBody: some View {
///         let colorScheme = useEnvironment(\.colorScheme)
///         Text(colorScheme == .dark ? "Dark mode" : "Light mode")
///     }
/// }
/// ```
@MainActor
public func useEnvironment<Value>(_ keyPath: KeyPath<EnvironmentValues, Value>) -> Value {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let environment: EnvironmentValues = guardFunction(context.states.filter({$0 is EnvironmentValues}).first) {
        EnvironmentValues()
    } as! EnvironmentValues
    return environment[keyPath: keyPath]
}
