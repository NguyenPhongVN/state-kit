/// An inline, anonymous mutable atom created by the `atom()` factory function.
///
/// `SKAtomRef` uses **reference identity** as its `Hashable` key — two distinct
/// `SKAtomRef` instances are always separate atoms in the store, even if they
/// have the same default value. This mirrors Jotai's `atom(initialValue)`.
///
/// ## Creating an inline atom
///
/// ```swift
/// // Declare once at module / type scope (not inside a view body!)
/// let counterAtom = atom(0)           // SKAtomRef<Int>
/// let nameAtom    = atom("Anonymous") // SKAtomRef<String>
/// ```
///
/// ## Using in a view
///
/// ```swift
/// @SKState(counterAtom) var count
/// @SKValue(counterAtom) var readOnly
/// ```
///
/// ## Why reference type?
///
/// Value-type atoms (structs) derive identity from their `Hashable` value.
/// Inline atoms created with `atom()` must be their own unique identity —
/// no two calls to `atom(0)` should share state. A reference type achieves
/// this because `===` (pointer equality) is always unique per allocation.
public final class SKAtomRef<Value>: SKStateAtom, @unchecked Sendable {

    // MARK: - Storage

    private let _defaultValue: @MainActor () -> Value

    // MARK: - Init

    /// Creates a new anonymous mutable atom with the given default producer.
    ///
    /// - Parameter defaultValue: A closure that produces the atom's initial
    ///   value. Evaluated once per store on first access.
    public init(_ defaultValue: @escaping @MainActor () -> Value) {
        _defaultValue = defaultValue
    }

    // MARK: - SKStateAtom

    public func defaultValue(context: SKAtomTransactionContext) -> Value {
        _defaultValue()
    }

    // MARK: - Hashable / Equatable (reference identity)

    public static func == (lhs: SKAtomRef, rhs: SKAtomRef) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
