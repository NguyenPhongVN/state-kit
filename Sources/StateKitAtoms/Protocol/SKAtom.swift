/// Base protocol for all atoms in `StateKitAtoms`.
///
/// An atom is the fundamental unit of state. Every atom:
/// - Has a unique identity derived from its `Hashable` conformance and Swift type.
/// - Produces a `Value` stored and tracked in `SKAtomStore`.
/// - Can be read and (if mutable) written through `SKAtomViewContext` or the
///   property wrappers `@SKValue`, `@SKState`, and `@SKTask`.
///
/// ## Conformance
///
/// Do not conform to `SKAtom` directly. Use one of the sub-protocols:
///
/// | Protocol                | Value kind                            |
/// |-------------------------|---------------------------------------|
/// | `SKStateAtom`           | Mutable, has a default value          |
/// | `SKValueAtom`           | Derived/read-only, watches atoms      |
/// | `SKTaskAtom`            | Async non-throwing → `AsyncPhase`     |
/// | `SKThrowingTaskAtom`    | Async throwing → `AsyncPhase`         |
/// | `SKPublisherAtom`       | Combine publisher → `PublisherPhase`  |
///
/// ## Swift 6.3 associated-type inference note
///
/// Due to a Swift 6.3 compiler bug (signal 5 crash in `ExprRewriter` when
/// `#expect` or similar macros type-check expressions involving `SKAtomBox<Value>`),
/// conforming types **must explicitly declare their associated types** rather than
/// relying on inference:
///
/// ```swift
/// // Required — avoids Swift 6.3 compiler crash
/// struct CounterAtom: SKStateAtom, Hashable {
///     typealias Value = Int                                // explicit
///     func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
/// }
///
/// struct FetchAtom: SKTaskAtom, Hashable {
///     typealias TaskSuccess = String                       // explicit
///     func task(context: SKAtomTransactionContext) async -> String { "ok" }
/// }
/// ```
///
/// ## Identity
///
/// Atom identity comes from both the `Hashable` value **and** the Swift type.
/// Two atoms of different types that happen to be equal under `==` are still
/// treated as different atoms in the store.
///
/// For named atoms:
///
/// ```swift
/// struct CounterAtom: SKStateAtom, Hashable {
///     func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
/// }
/// ```
///
/// For inline atoms, use the factory functions `atom()` and `selector()`.
public protocol SKAtom: Hashable, Sendable {

    /// The type of value this atom produces.
    associatedtype Value

    /// Returns the atom's reactive box from `store`, creating and initialising
    /// it on first access.
    ///
    /// - Important: This is an internal dispatch hook. Each sub-protocol
    ///   (`SKStateAtom`, `SKValueAtom`, …) provides its own default
    ///   implementation. Do not override it in concrete conforming types.
    /// - Note: Must be called on the main actor. The method itself carries no
    ///   actor annotation so it can appear in protocol requirements without
    ///   triggering conformance issues — callers are responsible for MainActor
    ///   isolation (all public API enforces this through `@MainActor` context).
    func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value>
}
