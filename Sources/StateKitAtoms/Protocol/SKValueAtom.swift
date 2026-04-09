/// A read-only derived atom whose value is computed from other atoms.
///
/// `SKValueAtom` is the atom equivalent of a computed property or Recoil's
/// `selector`. Its value is recomputed automatically whenever any atom it
/// watches changes.
///
/// ## Defining a derived atom
///
/// ```swift
/// struct DoubledCounterAtom: SKValueAtom, Hashable {
///     typealias Value = Int   // required in Swift 6.3 — see SKAtom docs
///     func value(context: SKAtomTransactionContext) -> Int {
///         context.watch(CounterAtom()) * 2
///     }
/// }
/// ```
///
/// Every call to `context.watch(_:)` creates a dependency edge in the graph.
/// When `CounterAtom` changes, `DoubledCounterAtom` is recomputed and views
/// subscribed to it re-render.
///
/// ## Using it in a view
///
/// ```swift
/// struct DoubledView: View {
///     @SKValue(DoubledCounterAtom()) var doubled
///
///     var body: some View { Text("\(doubled)") }
/// }
/// ```
///
/// ## Inline selectors
///
/// ```swift
/// let doubledAtom = selector { ctx in ctx.watch(counterAtom) * 2 }
/// ```
public protocol SKValueAtom: SKAtom {
    /// Computes and returns this atom's current value.
    ///
    /// Use `context.watch(_:)` inside this method to declare dependencies.
    /// All watched atoms are tracked: when any of them changes, this method
    /// will be called again and the result cached.
    ///
    /// - Parameter context: A transaction context for reading and watching
    ///   other atoms.
    @MainActor
    func value(context: SKAtomTransactionContext) -> Value
}

extension SKValueAtom {
    public func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value> {
        MainActor.assumeIsolated { store.valueBox(for: self) }
    }
}
