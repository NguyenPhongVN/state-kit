/// A mutable atom whose value can be read and written from any view.
///
/// `SKStateAtom` is the atom equivalent of SwiftUI's `@State`: it owns a
/// piece of state with a defined default value and exposes it to any view
/// that watches it.
///
/// ## Defining a named atom
///
/// ```swift
/// struct CounterAtom: SKStateAtom, Hashable {
///     typealias Value = Int   // required in Swift 6.3 — see SKAtom docs
///     func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
/// }
/// ```
///
/// ## Using it in a view
///
/// ```swift
/// struct CounterView: View {
///     @SKState(CounterAtom()) var count
///
///     var body: some View {
///         Stepper("\(count)", value: $count)
///     }
/// }
/// ```
///
/// ## Inline atoms
///
/// ```swift
/// let counterAtom = atom(0)           // SKAtomRef<Int>
/// @SKState(counterAtom) var count
/// ```
public protocol SKStateAtom: SKAtom {
    /// Returns the initial (default) value for this atom.
    ///
    /// Called once per store when the atom is first accessed. The `context`
    /// lets you read other atoms to compose defaults, but you should **not**
    /// call `context.watch()` here — defaults don't participate in the
    /// dependency graph.
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> Value
}

extension SKStateAtom {
    public func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value> {
        // All callers are on the main actor (SwiftUI views, @MainActor methods).
        // MainActor.assumeIsolated asserts this at runtime in debug builds.
        MainActor.assumeIsolated { store.stateBox(for: self) }
    }
}
