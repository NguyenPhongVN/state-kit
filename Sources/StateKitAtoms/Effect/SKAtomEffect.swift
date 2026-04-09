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

/// A `SKStateAtom` that also carries an `SKAtomEffect`.
///
/// Atoms conforming to this protocol declare their effect via the `effect`
/// property. The store will call the effect's lifecycle methods at appropriate
/// times.
public protocol SKStateAtomWithEffect: SKStateAtom {
    /// The type of effect associated with this atom.
    associatedtype Effect: SKAtomEffect where Effect.Value == Value

    /// Returns the effect instance for this atom.
    ///
    /// The effect is instantiated once per atom key per store.
    var effect: Effect { get }
}

// MARK: - Type-erased container (internal use)

/// Internal type-erasure wrapper used by `SKAtomStore` to store effects.
struct SKAtomEffectContainer {
    let initialized: @MainActor (SKAtomViewContext) -> Void
    let updated: @MainActor (SKAtomViewContext) -> Void
    let released: @MainActor () -> Void
}
