/// An inline, anonymous derived atom created by the `selector()` factory function.
///
/// `SKSelectorRef` is the read-only counterpart to `SKAtomRef`. It computes
/// its value from other atoms using the provided closure, and recomputes
/// automatically whenever a watched dependency changes.
///
/// Like `SKAtomRef`, it uses **reference identity** as its key so that each
/// call to `selector {}` produces a distinct atom.
///
/// ## Creating an inline selector
///
/// ```swift
/// let counterAtom  = atom(0)
/// let doubledAtom  = selector { ctx in ctx.watch(counterAtom) * 2 }
/// let labelAtom    = selector { ctx in "Count: \(ctx.watch(counterAtom))" }
/// ```
///
/// ## Using in a view
///
/// ```swift
/// @SKValue(doubledAtom) var doubled
/// ```
public final class SKSelectorRef<Value>: SKValueAtom, @unchecked Sendable {

    // MARK: - Storage

    private let _compute: @MainActor (SKAtomTransactionContext) -> Value

    // MARK: - Init

    /// Creates a new anonymous derived atom with the given computation.
    ///
    /// - Parameter compute: A closure that reads/watches other atoms and
    ///   returns the derived value. Every `context.watch(_:)` call inside
    ///   registers a reactive dependency.
    public init(_ compute: @escaping @MainActor (SKAtomTransactionContext) -> Value) {
        _compute = compute
    }

    // MARK: - SKValueAtom

    public func value(context: SKAtomTransactionContext) -> Value {
        _compute(context)
    }

    // MARK: - Hashable / Equatable (reference identity)

    public static func == (lhs: SKSelectorRef, rhs: SKSelectorRef) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
