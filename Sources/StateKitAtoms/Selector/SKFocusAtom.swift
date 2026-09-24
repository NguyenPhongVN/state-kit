import StateKit

// MARK: - SKFocusAtom

/// A read/write lens over one field of a state atom's value.
///
/// `SKFocusAtom` derives its value from a base state atom through a writable
/// key path — it never stores a copy. Reading the focus tracks the base
/// (the field updates whenever the base changes); writing the focus produces
/// an updated base value and writes it back, so the base atom and all of its
/// dependents see the change.
///
/// ```swift
/// let emailFocus = ProfileAtom().focus(\.email)
///
/// // In a view — reads are reactive:
/// @SKValue(emailFocus) var email
///
/// // Writes:
/// emailFocus.set("new@statekit.dev", in: container)
/// ```
///
/// - Note: Two lenses over different fields of the same base are distinct
///   atoms; re-creating the same lens yields the same store identity.
///
/// Sendability: `base` is `Sendable` (SKAtom requirement) and a key path is
/// an immutable value; the unchecked conformance documents that invariant.
public struct SKFocusAtom<Base: SKStateAtom, Field>: SKValueAtom, @unchecked Sendable where Base.Value: Sendable, Field: Sendable {

    /// The base atom whose value this lens projects.
    public let base: Base

    /// The key path from the base value to the focused field.
    public let keyPath: WritableKeyPath<Base.Value, Field>

    /// The focused field type.
    public typealias Value = Field

    /// Creates a lens over `base` focused on `keyPath`.
    public init(base: Base, keyPath: WritableKeyPath<Base.Value, Field>) {
        self.base = base
        self.keyPath = keyPath
    }

    // MARK: SKValueAtom

    /// Derives the field from the base atom's current value.
    @MainActor
    public func value(context: SKAtomTransactionContext) -> Field {
        context.watch(base)[keyPath: keyPath]
    }

    // MARK: Writing

    /// Writes `value` through the lens: the base atom's value is updated with
    /// only this field changed, and all of the base's dependents recompute.
    ///
    /// - Parameters:
    ///   - value: The new field value.
    ///   - store: The store where the base atom lives.
    @MainActor
    public func set(_ value: Field, in store: SKAtomStore) {
        var baseValue = store.stateBox(for: base).value
        baseValue[keyPath: keyPath] = value
        store.setStateValue(baseValue, for: base)
    }

    // MARK: Hashable / Equatable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(base)
        hasher.combine(keyPath)
    }

    public static func == (lhs: SKFocusAtom<Base, Field>, rhs: SKFocusAtom<Base, Field>) -> Bool {
        lhs.base == rhs.base && lhs.keyPath == rhs.keyPath
    }
}

// MARK: - `.focus(_:)`

public extension SKStateAtom where Value: Sendable {

    /// Creates a read/write lens over one field of this atom's value.
    ///
    /// Reads through the lens track this atom; `set(_:in:)` writes the field
    /// back so this atom (and its dependents) recompute.
    ///
    /// - Parameter keyPath: Writable path from this atom's value to a field.
    /// - Returns: A focus atom projecting the field as first-class state.
    func focus<Field>(_ keyPath: WritableKeyPath<Value, Field>) -> SKFocusAtom<Self, Field> {
        SKFocusAtom(base: self, keyPath: keyPath)
    }
}

// MARK: - Store convenience

public extension SKAtomStore {

    /// Writes through a focus atom: updates the base with only the focused
    /// field changed, then propagates to all dependents.
    ///
    /// - Parameters:
    ///   - value: The new field value.
    ///   - focus: The lens to write through.
    @MainActor
    func setValue<Field>(_ value: Field, for focus: SKFocusAtom<some SKStateAtom, Field>) where Field: Sendable {
        focus.set(value, in: self)
    }
}
