import StateKit

// MARK: - @Computed Example

/// Generates: typealias Computed = Bool
@Computed
struct IsAdult {
    func compute(context: AtomContext) -> Bool {
        let age = context.value(userAge)
        return age >= 18
    }
}

/// Usage:
/// let isAdult = context.value(IsAdult.self)

// MARK: - Alternative: Inline with @Atom

@Atom
struct IsAdultInline {
    func value(context: AtomContext) -> Bool {
        let age = context.value(userAge)
        return age >= 18
    }
}

// Note: @Computed is more semantically clear for derived computations
// Use @Computed when you want derived values, @ValueAtom for general values
