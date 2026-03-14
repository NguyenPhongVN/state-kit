import SwiftUI

/// Creates a stateful value associated with the current hook position.
///
/// This function behaves similarly to React's `useState`. It must be called
/// inside a `HookView` (or wherever `HookRuntime.current` is available), and
/// calls to `useState` must remain in a stable order across renders.
///
/// On the first render for a given hook index, the state is initialized with
/// the provided `initial` value. On subsequent renders, the previously stored
/// value is returned and the `initial` value is ignored.
///
/// Updating the returned `StateSignal`'s `value` will trigger the appropriate
/// re-render driven by the hook runtime.
///
/// - Parameter initial: The initial value to use for this state on first render.
/// - Returns: A `StateSignal` wrapping the current state value.
///
/// ### Example
/// ```swift
/// struct CounterView: HookView {
///     var body: some View {
///         let count = useState(0)
///
///         VStack {
///             Text("Count: \(count.value)")
///             Button("Increment") {
///                 count.value += 1
///             }
///         }
///     }
/// }
/// ```

@MainActor
private func _useState<T>(_ initial: T) -> StateSignal<T> {
    
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside HookView")
    }
    
    let index = context.nextIndex()
    
    if context.states.count <= index {
        context.states.append(StateSignal(initial))
    }
    
    return context.states[index] as! StateSignal<T>
}

/// Convenience wrapper around `useState` that returns a tuple of the current
/// value and a setter function.
///
/// This is useful when you prefer working with a plain value and a `set` closure,
/// instead of a `StateSignal`. The returned setter replaces the state with the
/// provided value.
///
/// - Parameter initial: The initial value to use for this state on first render.
/// - Returns: A tuple containing the current value and a setter closure.
///
/// ### Example
/// ```swift
/// struct SimpleCounterView: HookView {
///     var body: some View {
///         let (count, setCount) = useStateSet(0)
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

/// Creates a SwiftUI `Binding` backed by hook-based state.
///
/// This function is a convenience wrapper around `useState` that exposes
/// the underlying state as a `Binding<T>`. It is ideal for wiring HookKit
/// state directly into standard SwiftUI controls such as `TextField`,
/// `Toggle`, and `Slider`.
///
/// - Parameter initial: The initial value to use for this state on first render.
/// - Returns: A `Binding` that reads and writes the underlying hook state.
///
/// ### Example
/// ```swift
/// struct NameFormView: HookView {
///     var body: some View {
///         let name = useStateBinding("")
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
