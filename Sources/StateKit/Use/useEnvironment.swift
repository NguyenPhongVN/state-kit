import SwiftUI
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
        fatalError("\(#function) must be used inside StateRuntime")
    }
    // `injectedEnvironment` is set by StateScope before each render.
    // Fall back to a default EnvironmentValues when no StateScope is present.
    let environment = (context.injectedEnvironment as? EnvironmentValues) ?? EnvironmentValues()
    return environment[keyPath: keyPath]
}
