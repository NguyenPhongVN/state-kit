import SwiftUI

/// Creates a stateful value associated with the current hook position.
///
/// This is the internal implementation shared by `useState(_:)` and
/// `useBinding(_:)`. It must be called while `StateRuntime.current` is set —
/// i.e. inside the `@ViewBuilder` closure of a `StateScope`, or inside
/// `stateBody` of a `StateView`.
///
/// On the first render for a given hook index the state is initialized with
/// `initial` and stored as a new `StateSignal` in `StateRuntime.current.states`.
/// On every subsequent render the existing `StateSignal` at that index is
/// returned and `initial` is ignored.
///
/// Hook identity is determined by call-site order via `context.nextIndex()`,
/// so hooks must always be called in the same order across renders — never
/// inside conditionals or loops.
///
/// Mutating the returned `StateSignal.value` causes `StateScope` to re-render
/// because `StateSignal` is `@Observable` and `StateScope` holds the context
/// as a `@State` property.
///
/// - Parameter initial: The value used to initialize this state slot on the
///   first render. Ignored on all subsequent renders.
/// - Returns: The `StateSignal<T>` stored at the current hook index.

@MainActor
private func _useState<T>(_ initial: T) -> StateSignal<T> {

    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        context.states.append(StateSignal(initial))
    }

    return context.states[index] as! StateSignal<T>
}

/// Returns the current state value and a setter closure for the current hook
/// position.
///
/// This is a convenience wrapper around `_useState(_:)` that unpacks the
/// `StateSignal` into a plain value and a `(T) -> Void` setter. Use this
/// when you prefer working with immutable values and explicit setter calls
/// rather than a mutable signal object.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// Calling the setter writes to the underlying `StateSignal.value`, which
/// triggers a re-render of the enclosing `StateScope` via `@Observable`.
///
/// - Parameter initial: The initial value for this state slot on the first
///   render. Ignored on all subsequent renders.
/// - Returns: A tuple of `(currentValue, setter)` where `setter` replaces
///   the stored state and schedules a re-render.
///
/// ### Example
/// ```swift
/// struct CounterView: StateView {
///     var stateBody: some View {
///         let (count, setCount) = useState(0)
///
///         VStack {
///             Text("Count: \(count)")
///             Button("Increment") {
///                 setCount(count + 1)
///             }
///         }
///     }
/// }
/// ```

@MainActor
public func useState<T>(_ initial: T) -> (T, ((T) -> Void)) {
    let value = _useState(initial)
    let setValue: (T) -> Void = { value.value = $0 }
    return (value.value, setValue)
}

/// Returns a SwiftUI `Binding` backed by hook-based state at the current
/// hook position.
///
/// This is a convenience wrapper around `_useState(_:)` that exposes the
/// underlying `StateSignal` as a `Binding<T>`. Use this when you need to
/// pass state directly into standard SwiftUI controls such as `TextField`,
/// `Toggle`, or `Slider` that require a `Binding`.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// The binding's getter reads `StateSignal.value`; its setter writes to
/// `StateSignal.value`, triggering a re-render of the enclosing `StateScope`
/// via `@Observable`.
///
/// - Parameter initial: The initial value for this state slot on the first
///   render. Ignored on all subsequent renders.
/// - Returns: A `Binding<T>` whose reads and writes go through the underlying
///   `StateSignal`.
///
/// ### Example
/// ```swift
/// struct NameFormView: StateView {
///     var stateBody: some View {
///         let name = useBinding("")
///
///         VStack {
///             TextField("Name", text: name)
///             Text("Hello, \(name.wrappedValue)")
///         }
///     }
/// }
/// ```

@MainActor
public func useBinding<T>(_ initial: T) -> Binding<T> {

    let value = _useState(initial)

    return Binding {
        value.value
    } set: { newValue in
        value.value = newValue
    }

}
