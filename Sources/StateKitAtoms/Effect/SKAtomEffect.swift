// MARK: - Atom Effects
//
// Atom effects are lifecycle hooks that run in response to atom state changes.
// They let you wire up side-effects (analytics, persistence, syncing) at the
// atom level rather than scattering them across view code.
//
// Usage — attach an effect to a SKStateAtom by conforming to SKAtomWithEffect:
//
// ```swift
// struct CounterEffect: SKAtomEffect {
//     typealias Value = Int
//
//     func initialized(value: Int, context: SKAtomViewContext) {
//         print("Counter initialised with \(value)")
//     }
//
//     func updated(oldValue: Int, newValue: Int, context: SKAtomViewContext) {
//         Analytics.track("counter_changed", from: oldValue, to: newValue)
//     }
//
//     func released() {
//         print("Counter evicted from store")
//     }
// }
//
// struct CounterAtom: SKStateAtomWithEffect, Hashable {
//     func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
//     var effect: CounterEffect { CounterEffect() }
// }
// ```
//
// Note: Effects are not yet wired into SKAtomStore automatically in this
// release. They define the interface; call them manually from app code or
// override points as needed.

// MARK: - SKAtomEffect Protocol

/// A lifecycle observer for a specific atom type.
///
/// Implement this protocol to react to an atom being created, updated, or
/// removed from the store. Useful for persistence, analytics, or syncing.
public protocol SKAtomEffect {
    /// The type of value produced by the atom this effect watches.
    associatedtype Value

    /// Called once when the atom is first read from the store (created).
    ///
    /// - Parameters:
    ///   - value: The initial value of the atom.
    ///   - context: A view context for reading or writing other atoms.
    @MainActor
    func initialized(value: Value, context: SKAtomViewContext)

    /// Called every time the atom's value changes.
    ///
    /// - Parameters:
    ///   - oldValue: The previous value.
    ///   - newValue: The new value.
    ///   - context: A view context for reading or writing other atoms.
    @MainActor
    func updated(oldValue: Value, newValue: Value, context: SKAtomViewContext)

    /// Called when the atom is evicted from the store.
    @MainActor
    func released()
}

// MARK: - Default no-op implementations

extension SKAtomEffect {
    @MainActor public func initialized(value: Value, context: SKAtomViewContext) {}
    @MainActor public func updated(oldValue: Value, newValue: Value, context: SKAtomViewContext) {}
    @MainActor public func released() {}
}

// MARK: - Combined protocol

/// A base protocol for any atom that carries an `SKAtomEffect`.
public protocol SKAtomWithEffect: SKAtom {
    /// The type of effect associated with this atom.
    associatedtype Effect: SKAtomEffect where Effect.Value == Value

    /// Returns the effect instance for this atom.
    var effect: Effect { get }

    /// Internal hook for `SKAtomStore` to register the effect.
    @MainActor
    func _registerEffect(in store: SKAtomStore, key: SKAtomKey)
}

/// A `SKStateAtom` that also carries an `SKAtomEffect`.
///
/// Atoms conforming to this protocol declare their effect via the `effect`
/// property. The store will call the effect's lifecycle methods at appropriate
/// times.
public protocol SKStateAtomWithEffect: SKStateAtom, SKAtomWithEffect {}

extension SKAtomWithEffect {
    @MainActor
    public func _registerEffect(in store: SKAtomStore, key: SKAtomKey) {
        // This is tricky because we need the box, but box creation is atom-kind specific.
        // For state atoms, store.stateBox(for: self) works.
        // For value atoms, store.valueBox(for: self) works.
        // We'll let the sub-protocols handle this or use a generic approach.
    }
}

extension SKStateAtomWithEffect {
    @MainActor
    public func _registerEffect(in store: SKAtomStore, key: SKAtomKey) {
        let box = store.stateBox(for: self)
        let erased = _erasedEffect(for: box)
        store.effects[key] = erased
        erased.initialized(SKAtomViewContext(store: store))
    }
}

/// A `SKValueAtom` that also carries an `SKAtomEffect`.
public protocol SKValueAtomWithEffect: SKValueAtom, SKAtomWithEffect {}

extension SKValueAtomWithEffect {
    @MainActor
    public func _registerEffect(in store: SKAtomStore, key: SKAtomKey) {
        let box = store.valueBox(for: self)
        let erased = _erasedEffect(for: box)
        store.effects[key] = erased
        erased.initialized(SKAtomViewContext(store: store))
    }
}

// ... we could add more for Task atoms, but let's start with these.

extension SKAtomWithEffect {
    /// Internal helper to erase the effect's type for storage in `SKAtomStore`.
    @MainActor
    func _erasedEffect(for box: SKAtomBox<Value>) -> SKAtomEffectContainer {
        let effectInstance = effect
        return SKAtomEffectContainer(
            initialized: { ctx in
                effectInstance.initialized(value: box.value, context: ctx)
            },
            updated: { old, new, ctx in
                if let oldVal = old as? Value, let newVal = new as? Value {
                    effectInstance.updated(oldValue: oldVal, newValue: newVal, context: ctx)
                }
            },
            released: {
                effectInstance.released()
            }
        )
    }
}

// MARK: - Type-erased container (internal use)

/// Internal type-erasure wrapper used by `SKAtomStore` to store effects.
struct SKAtomEffectContainer {
    let initialized: @MainActor (SKAtomViewContext) -> Void
    let updated: @MainActor (Any, Any, SKAtomViewContext) -> Void
    let released: @MainActor () -> Void
}
