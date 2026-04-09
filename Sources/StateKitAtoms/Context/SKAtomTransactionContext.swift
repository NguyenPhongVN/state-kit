/// A read/watch context passed to atom production methods.
///
/// `SKAtomTransactionContext` is the context that derived atoms (`SKValueAtom`)
/// receive when their `value(context:)` method is called, and that async atoms
/// receive when their `task(context:)` method is called.
///
/// ## Dependency tracking
///
/// - `watch(_:)` — reads another atom's value **and** records a dependency edge
///   in the graph. If the watched atom later changes, the current atom will be
///   recomputed automatically.
/// - `read(_:)` — reads another atom's value **without** recording a dependency.
///   Use this when you want the current value but don't need reactive updates.
///
/// ## Mutation
///
/// - `set(_:for:)` — writes a new value to a `SKStateAtom`. Triggers downstream
///   propagation as usual.
/// - `reset(_:)` — resets a `SKStateAtom` to its default value.
///
/// - Note: This type is `@MainActor` because all atom operations are main-thread
///   only. Atom production closures are always invoked on the main actor.
@MainActor
public struct SKAtomTransactionContext {

    // MARK: - Internal

    private let store: SKAtomStore

    /// The key of the atom currently being computed, used to record dependency
    /// edges. `nil` when the context is used outside a derivation (e.g. during
    /// default value initialisation or from a view).
    let currentKey: SKAtomKey?

    init(store: SKAtomStore, currentKey: SKAtomKey?) {
        self.store = store
        self.currentKey = currentKey
    }

    // MARK: - Reading

    /// Reads another atom's current value and records a dependency edge so that
    /// the *current* atom is recomputed whenever `atom` changes.
    ///
    /// - Parameter atom: The atom to read.
    /// - Returns: The atom's current value.
    public func watch<A: SKAtom>(_ atom: A) -> A.Value {
        let watchedKey = SKAtomKey(atom)
        if let current = currentKey {
            store.addGraphDependency(from: current, to: watchedKey)
        }
        return atom._getOrCreateBox(in: store).value
    }

    /// Reads another atom's current value without creating a dependency edge.
    ///
    /// Prefer `watch(_:)` inside `SKValueAtom.value(context:)`. Use `read(_:)`
    /// in `SKTaskAtom.task(context:)` or in one-shot read scenarios where you
    /// don't need reactive invalidation.
    ///
    /// - Parameter atom: The atom to read.
    /// - Returns: The atom's current value.
    public func read<A: SKAtom>(_ atom: A) -> A.Value {
        atom._getOrCreateBox(in: store).value
    }

    // MARK: - Mutation

    /// Writes a new value to `atom` and propagates the change downstream.
    ///
    /// - Parameters:
    ///   - value: The new value.
    ///   - atom: The mutable atom to update.
    public func set<A: SKStateAtom>(_ value: A.Value, for atom: A) {
        store.setStateValue(value, for: atom)
    }

    /// Resets `atom` to the value returned by its `defaultValue(context:)`.
    ///
    /// - Parameter atom: The mutable atom to reset.
    public func reset<A: SKStateAtom>(_ atom: A) {
        store.resetStateValue(for: atom)
    }
}
