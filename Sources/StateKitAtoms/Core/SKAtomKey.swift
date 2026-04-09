/// Unique, type-safe identity for an atom in `SKAtomStore`.
///
/// Combines the atom's own `Hashable` identity with its Swift metatype so that
/// two different atom types with accidentally equal hash values are never
/// confused with one another.
///
/// ```swift
/// struct CounterAtom: SKStateAtom { … }
/// struct LabelAtom:   SKStateAtom { … }
///
/// SKAtomKey(CounterAtom()) != SKAtomKey(LabelAtom())  // distinct even if both hash to 0
/// ```
// AnyHashable is not Sendable; we use @unchecked Sendable because atom keys
// are always created and used on @MainActor, making cross-actor send impossible
// in normal usage.
public struct SKAtomKey: Hashable, @unchecked Sendable {

    /// The atom's own identity, type-erased for storage.
    let atomID: AnyHashable

    /// The atom type's metatype identifier — distinguishes types with equal hash values.
    let typeID: ObjectIdentifier

    /// Creates a key that uniquely identifies `atom`.
    public init<A: SKAtom>(_ atom: A) {
        atomID = AnyHashable(atom)
        typeID = ObjectIdentifier(A.self)
    }
}
