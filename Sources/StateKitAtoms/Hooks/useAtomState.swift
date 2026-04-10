import SwiftUI
import StateKit

// MARK: - useAtomValue

/// Reads any atom's current value and subscribes the enclosing `StateScope`
/// to future changes.
///
/// Works with every atom kind — `SKStateAtom`, `SKValueAtom`, `SKTaskAtom`,
/// and `SKThrowingTaskAtom`. For task atoms the returned value is an
/// `AsyncPhase<Success>`.
///
/// The atom's `SKAtomBox` is `Observable`. Accessing `.value` inside a
/// `StateScope` body registers a dependency, so any future write to that
/// atom automatically re-renders the view — exactly like reading a
/// `@Published` property on an `@ObservableObject`, but scoped to the
/// individual atom.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// in a stable call-order position (no conditionals or loops around hook
/// calls).
///
/// ```swift
/// struct CounterView: StateView {
///     var stateBody: some View {
///         let count = useAtomValue(CounterAtom())
///         Text("Count: \(count)")
///     }
/// }
/// ```
///
/// - Parameter atom: The atom to observe.
/// - Returns: The atom's current value.
@MainActor
public func useAtomValue<A: SKAtom>(_ atom: A) -> A.Value {
    let store = useEnvironment(\.skAtomStore)
    return atom._getOrCreateBox(in: store).value
}

// MARK: - useAtomState

/// Returns the current value and a setter for a mutable `SKStateAtom`,
/// bridging global atom state into the hook-based rendering model.
///
/// This is the atom equivalent of `useState(_:)`: the tuple API is identical,
/// but the value lives in `SKAtomStore` rather than a `StateContext` slot.
/// All views that observe the same atom — whether via `useAtomState`,
/// `@SKState`, or `useAtomValue` — re-render together when the value changes.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`.
///
/// ```swift
/// let counterAtom = atom(0)
///
/// struct CounterView: StateView {
///     var stateBody: some View {
///         // Local hook state (view-scoped)
///         let (localCount, setLocalCount) = useState(0)
///
///         // Global atom state (shared across views)
///         let (globalCount, setGlobalCount) = useAtomState(counterAtom)
///
///         VStack {
///             Text("Local: \(localCount)")
///             Text("Global: \(globalCount)")
///             Button("+1 Local") { setLocalCount(localCount + 1) }
///             Button("+1 Global") { setGlobalCount(globalCount + 1) }
///         }
///     }
/// }
/// ```
///
/// - Parameter atom: The mutable atom to observe and write.
/// - Returns: A `(currentValue, setter)` tuple. Calling `setter` updates the
///   atom in the store and triggers re-renders in all subscribed views.
@MainActor
public func useAtomState<A: SKStateAtom>(_ atom: A) -> (A.Value, (A.Value) -> Void) {
    let store = useEnvironment(\.skAtomStore)
    let value = store.stateBox(for: atom).value
    let set: (A.Value) -> Void = { [atom] newValue in
        store.setStateValue(newValue, for: atom)
    }
    return (value, set)
}

// MARK: - useAtomBinding

/// Returns a `Binding<Value>` backed by a mutable `SKStateAtom`.
///
/// This is the atom equivalent of `useBinding(_:)`: the binding reads and
/// writes the atom's value in `SKAtomStore`. Use it wherever SwiftUI controls
/// require a `Binding` (e.g. `TextField`, `Toggle`, `Slider`, `Stepper`).
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`.
///
/// ```swift
/// struct NameFormView: StateView {
///     var stateBody: some View {
///         let name = useAtomBinding(NameAtom())
///
///         VStack {
///             TextField("Name", text: name)
///             Text("Hello, \(name.wrappedValue)")
///         }
///     }
/// }
/// ```
///
/// - Parameter atom: The mutable atom to bind to.
/// - Returns: A `Binding<A.Value>` that reads and writes through `SKAtomStore`.
@MainActor
public func useAtomBinding<A: SKStateAtom>(_ atom: A) -> Binding<A.Value> {
    let store = useEnvironment(\.skAtomStore)
    return Binding {
        store.stateBox(for: atom).value
    } set: { newValue in
        store.setStateValue(newValue, for: atom)
    }
}

// MARK: - useAtomReset

/// Returns a closure that resets a `SKStateAtom` to its default value.
///
/// ```swift
/// struct CounterView: StateView {
///     var stateBody: some View {
///         let (count, setCount) = useAtomState(CounterAtom())
///         let resetCount = useAtomReset(CounterAtom())
///
///         HStack {
///             Button("+1") { setCount(count + 1) }
///             Button("Reset") { resetCount() }
///         }
///     }
/// }
/// ```
///
/// - Parameter atom: The mutable atom to reset.
/// - Returns: A `() -> Void` closure that restores `atom` to its default.
@MainActor
public func useAtomReset<A: SKStateAtom>(_ atom: A) -> () -> Void {
    let store = useEnvironment(\.skAtomStore)
    return { store.resetStateValue(for: atom) }
}
