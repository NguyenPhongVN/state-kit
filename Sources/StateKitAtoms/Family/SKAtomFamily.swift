// MARK: - Atom Family
//
// An atom family is a function from an ID to an atom.  Each unique ID maps to
// a distinct atom in the store, sharing the same production logic but holding
// independent state.
//
// Equivalent to Recoil's `atomFamily` / `selectorFamily` and Jotai's
// parameterised atoms.
//
// ## Example
//
// ```swift
// // Declare once at module scope
// let userAtom = atomFamily { (id: String) in
//     User(id: id)
// }
//
// // Per-user atom — each ID is independent
// @SKState(userAtom("alice")) var alice
// @SKState(userAtom("bob"))   var bob
// ```

// MARK: - Internal shared definition

/// Shared identity object for atoms produced by the same `atomFamily` call.
///
/// Stored as a reference so that `SKAtomFamilyMember` values produced by the
/// same family call share the same `ObjectIdentifier`, giving them the same
/// namespace in `SKAtomKey` while remaining separated by their `id`.
final class SKAtomFamilyDefinition<ID: Hashable & Sendable, Value>: @unchecked Sendable {
    let producer: (ID) -> Value
    init(producer: @escaping (ID) -> Value) { self.producer = producer }
}

// MARK: - SKAtomFamilyMember (State)

/// A concrete `SKStateAtom` produced by `atomFamily`.
///
/// Two members of the same family with the same `id` are equal; members with
/// different `id`s are distinct atoms.
public struct SKAtomFamilyMember<ID: Hashable & Sendable, Value: Sendable>: SKStateAtom {

    let definition: SKAtomFamilyDefinition<ID, Value>
    public let id: ID

    // MARK: SKStateAtom

    public func defaultValue(context: SKAtomTransactionContext) -> Value {
        definition.producer(id)
    }

    // MARK: Hashable / Equatable

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.definition === rhs.definition && lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(definition))
        hasher.combine(id)
    }
}

// MARK: - SKSelectorFamilyMember (Value/derived)

/// Shared definition for selector families.
final class SKSelectorFamilyDefinition<ID: Hashable & Sendable, Value>: @unchecked Sendable {
    let compute: @MainActor (ID, SKAtomTransactionContext) -> Value
    init(compute: @escaping @MainActor (ID, SKAtomTransactionContext) -> Value) {
        self.compute = compute
    }
}

/// A concrete `SKValueAtom` produced by `selectorFamily`.
public struct SKSelectorFamilyMember<ID: Hashable & Sendable, Value: Sendable>: SKValueAtom {

    let definition: SKSelectorFamilyDefinition<ID, Value>
    public let id: ID

    // MARK: SKValueAtom

    public func value(context: SKAtomTransactionContext) -> Value {
        definition.compute(id, context)
    }

    // MARK: Hashable / Equatable

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.definition === rhs.definition && lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(definition))
        hasher.combine(id)
    }
}

// MARK: - Factory functions

/// Creates a family of mutable atoms parameterised by `ID`.
///
/// ```swift
/// let userAtom = atomFamily { (id: String) in
///     User.placeholder(id: id)
/// }
///
/// @SKState(userAtom("alice")) var alice
/// ```
///
/// - Parameter producer: A function from `ID` to the atom's default value.
/// - Returns: A function `(ID) -> SKAtomFamilyMember<ID, Value>`.
public func atomFamily<ID: Hashable & Sendable, Value: Sendable>(
    _ producer: @escaping (ID) -> Value
) -> (ID) -> SKAtomFamilyMember<ID, Value> {
    let definition = SKAtomFamilyDefinition(producer: producer)
    return { id in SKAtomFamilyMember(definition: definition, id: id) }
}

/// Creates a family of derived atoms parameterised by `ID`.
///
/// ```swift
/// let filteredAtom = selectorFamily { (tag: String, ctx: SKAtomTransactionContext) in
///     ctx.watch(allPostsAtom).filter { $0.tags.contains(tag) }
/// }
///
/// @SKValue(filteredAtom("swift")) var swiftPosts
/// ```
///
/// - Parameter compute: A closure receiving `(id, context)` that watches/reads
///   other atoms and returns the derived value.
/// - Returns: A function `(ID) -> SKSelectorFamilyMember<ID, Value>`.
public func selectorFamily<ID: Hashable & Sendable, Value: Sendable>(
    _ compute: @escaping @MainActor (ID, SKAtomTransactionContext) -> Value
) -> (ID) -> SKSelectorFamilyMember<ID, Value> {
    let definition = SKSelectorFamilyDefinition(compute: compute)
    return { id in SKSelectorFamilyMember(definition: definition, id: id) }
}
