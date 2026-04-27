// MARK: - UpdateStrategy

/// Determines when a hook should re-run its operation.
///
/// Every hook that supports conditional re-execution (`useEffect`, `useMemo`,
/// `useAsync`, `usePublisher`, `useAsyncSequence`, `useCallback`) accepts an
/// `UpdateStrategy`. On each render the hook compares the stored
/// `Dependency` from the previous render against the one passed on this
/// render using `!=`. If they differ the operation re-runs; if they are
/// equal it does not.
///
/// Use the static factory members to construct strategies:
/// - `.once` — run exactly once, never re-run.
/// - `.preserved(by:)` — re-run whenever a dependency value changes.
public struct UpdateStrategy {

    /// The type-erased dependency value compared between renders to decide
    /// whether to re-run the hook operation.
    public let dependency: Dependency

    /// Creates a strategy from any `Equatable` dependency value.
    ///
    /// The value is wrapped in a `Dependency` container that captures its
    /// equality semantics at this point, allowing hooks to compare it on
    /// subsequent renders without knowing its concrete type.
    ///
    /// - Parameter dependency: An `Equatable` value used to determine whether
    ///   the hook should re-run. The hook re-runs when this value is not equal
    ///   to the one stored from the previous render.
    public init(dependency: any Equatable) {
        self.dependency = Dependency(dependency)
    }
}

// MARK: - Static factories

public extension UpdateStrategy {

    /// A strategy that runs the hook operation exactly once — on the first
    /// render — and never re-runs it on subsequent renders.
    ///
    /// Implemented with a local `Unique` struct that has no stored properties.
    /// Because `Unique` is `Equatable` and structurally empty, `Unique() == Unique()`
    /// is always `true`. This means the stored dependency never changes between
    /// renders, so the hook never re-triggers after the first run.
    static var once: Self {
        struct Unique: Equatable {}
        return self.init(dependency: Unique())
    }

    /// Returns a strategy that re-runs the hook whenever `value` changes.
    ///
    /// Wraps an `Equatable` value in a `Dependency` container. The hook
    /// compares the stored dependency against this value on each render using
    /// `Dependency.==`; if they differ the hook operation re-runs.
    ///
    /// Use this overload when the dependency is any single `Equatable` value
    /// that is not also `Hashable`.
    ///
    /// - Parameter value: The dependency to track. The hook re-runs when
    ///   this value is not equal to the one from the previous render.
    static func preserved(by value: any Equatable) -> Self {
        self.init(dependency: value)
    }

    /// Returns a strategy that re-runs the hook whenever `value` changes.
    ///
    /// `Hashable` overload of `preserved(by: any Equatable)`. Provided to
    /// avoid ambiguity at call sites where the compiler resolves the argument
    /// to `any Hashable` rather than `any Equatable`.
    ///
    /// - Parameter value: The `Hashable` dependency to track.
    static func preserved(by value: any Hashable) -> Self {
        self.init(dependency: value)
    }

    /// Returns a strategy that re-runs the hook whenever any value in the
    /// variadic list changes.
    ///
    /// Collects one or more `AnyHashable` dependencies into an array and
    /// wraps the array as a single `Dependency`. The hook re-runs when the
    /// array is not equal to the one stored from the previous render.
    ///
    /// - Parameter value: One or more `AnyHashable` dependencies to track.
    static func preserved(by value: AnyHashable...) -> Self {
        self.init(dependency: value)
    }

    /// Returns a strategy that re-runs the hook whenever any value in `value`
    /// changes.
    ///
    /// Array overload of the variadic `preserved(by: AnyHashable...)`. Use
    /// this when the dependency list is already assembled as an `[AnyHashable]`
    /// rather than passed as individual arguments.
    ///
    /// - Parameter value: An array of `AnyHashable` dependencies to track.
    static func preserved(by value: [any Hashable]) -> Self {
        self.init(dependency: value.map { AnyHashable($0) })
    }

    /// Returns a strategy that re-runs the hook whenever the value produced
    /// by `value()` changes.
    ///
    /// Evaluates the closure immediately and delegates to
    /// `preserved(by: any Equatable)`. Useful when the dependency is
    /// computed rather than stored — the closure is evaluated once per
    /// render at the hook call site.
    ///
    /// - Parameter value: A closure that returns an `Equatable` dependency.
    static func preserved(by value: () -> any Equatable) -> Self {
        .preserved(by: value())
    }

    /// Returns a strategy that re-runs the hook whenever the value produced
    /// by `value()` changes.
    ///
    /// `Hashable` overload of the closure variant. Evaluates the closure
    /// immediately and delegates to `preserved(by: any Hashable)`.
    ///
    /// - Parameter value: A closure that returns a `Hashable` dependency.
    static func preserved(by value: () -> any Hashable) -> Self {
        .preserved(by: value())
    }

    /// Returns a strategy that re-runs the hook whenever any value produced
    /// by the closures in the variadic list changes.
    ///
    /// Each closure is evaluated immediately via `compactMap`, discarding any
    /// that return `nil` after type erasure, and the resulting `[AnyHashable]`
    /// is passed to `preserved(by: [AnyHashable])`.
    ///
    /// - Parameter value: One or more closures each returning an `AnyHashable`
    ///   dependency.
    static func preserved(by value: (() -> any Hashable)...) -> Self {
        .preserved(by: value.compactMap({ $0() }))
    }

    /// Returns a strategy that re-runs the hook whenever any value in the
    /// array produced by `value()` changes.
    ///
    /// Evaluates the closure immediately and delegates to
    /// `preserved(by: [AnyHashable])`.
    ///
    /// - Parameter value: A closure that returns an array of `AnyHashable`
    ///   dependencies.
    static func preserved(by value: () -> [any Hashable]) -> Self {
        .preserved(by: value())
    }
}

// MARK: - Dependency

public extension UpdateStrategy {

    /// A type-erased, `Equatable` wrapper around a hook's dependency value.
    ///
    /// `Dependency` serves the same purpose as `AnyEquatable` in
    /// `AnyEquatable.swift` but is scoped to `UpdateStrategy`: it captures
    /// the equality semantics of any `Equatable` value at init time, allowing
    /// hooks to compare dependencies stored as `Dependency` without knowing
    /// the underlying concrete type.
    ///
    /// Hooks compare the stored `Dependency` from the previous render against
    /// the one on the current render via `!=`. If they differ the hook
    /// re-runs its operation.
    ///
    /// ### Double-wrap prevention
    /// If the value passed to `init` is already a `Dependency`, the initialiser
    /// assigns `self = key` directly to avoid nested wrapping.
    struct Dependency: Equatable {
        private let value: any Equatable
        private let equals: (Self) -> Bool

        /// Wraps `value` in a type-erased dependency container.
        ///
        /// The equality closure is captured at this point, preserving the
        /// concrete type of `value` so that `==` can perform a type-safe
        /// comparison at runtime via `areEqual`.
        ///
        /// - Parameter value: Any `Equatable` value to use as a dependency.
        public init(_ value: any Equatable) {
            if let key = value as? Self {
                self = key
                return
            }
            self.value = value
            self.equals = { other in
                areEqual(value, other.value)
            }
        }

        /// Returns `true` if both `Dependency` values wrap equal underlying
        /// values of the same concrete type; `false` otherwise.
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.equals(rhs)
        }
    }
}
