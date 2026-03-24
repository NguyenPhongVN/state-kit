import Foundation

/// A type-erased `Equatable` wrapper that enables equality comparison between
/// two values whose concrete types are only known at runtime.
///
/// Swift's `Equatable` protocol requires both sides of `==` to share the same
/// concrete type at compile time. `AnyEquatable` lifts this restriction by
/// capturing an equality closure at initialisation time, enabling two
/// `AnyEquatable` values to be compared via `==` even when their underlying
/// types differ.
///
/// Used internally by `UpdateStrategy.Dependency` so that hook dependency
/// values of any `Equatable` type can be compared uniformly without exposing
/// the concrete type to the hook runtime.
///
/// ### Double-wrap prevention
/// If the value passed to `init` is already an `AnyEquatable`, the initialiser
/// assigns `self = key` directly, preventing unnecessary nesting.
fileprivate struct AnyEquatable: Equatable {
    private let value: any Equatable
    private let equals: (Self) -> Bool

    /// Wraps `value` in a type-erased equality container.
    ///
    /// The equality closure is captured at this point, preserving the
    /// concrete type of `value` so that `==` can perform a type-safe
    /// comparison at runtime.
    ///
    /// - Parameter value: Any `Equatable` value to wrap.
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

    /// Returns `true` if both `AnyEquatable` values wrap equal underlying
    /// values of the same concrete type; `false` otherwise.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.equals(rhs)
    }
}

// MARK: - Equatable helpers

fileprivate extension Equatable {

    /// Returns `true` if `self` equals `other`.
    ///
    /// Attempts to cast `other` to `Self` for a direct comparison. If the
    /// cast fails — meaning the two values have different concrete types —
    /// the comparison is retried from the other side via `isExactlyEqual`,
    /// which attempts to cast `self` to `other`'s type. Returns `false` if
    /// neither cast succeeds.
    ///
    /// - Parameter other: Any `Equatable` value to compare against.
    func isEqual(_ other: any Equatable) -> Bool {
        guard let other = other as? Self else {
            return other.isExactlyEqual(self)
        }
        return self == other
    }

    /// Returns `true` if `self` equals `other`.
    ///
    /// Guards that `other` conforms to `Equatable` then delegates to
    /// `isEqual(_ other: any Equatable)`.
    ///
    /// - Parameter other: Any value. Returns `false` if not `Equatable`.
    func isEqual(_ other: any Any) -> Bool {
        guard let other = other as? any Equatable else {
            return false
        }
        return isEqual(other)
    }

    /// Returns `true` if `self` equals `other`.
    ///
    /// Opaque-type overload of `isEqual(_ other: any Any)`. Guards that
    /// `other` conforms to `Equatable` then delegates to
    /// `isEqual(_ other: any Equatable)`.
    ///
    /// - Parameter other: Any value. Returns `false` if not `Equatable`.
    func isEqual(_ other: some Any) -> Bool {
        guard let other = other as? any Equatable else {
            return false
        }
        return isEqual(other)
    }

    /// Returns `true` if `other` can be cast to `Self` and equals `self`.
    ///
    /// Unlike `isEqual`, this method does not retry the comparison from the
    /// opposite side. It is used as a fallback by `isEqual` when the initial
    /// cast in the caller's direction fails, allowing one of the two types
    /// to act as the "anchor" for the type cast.
    ///
    /// - Parameter other: Any `Equatable` value to compare against.
    private func isExactlyEqual(_ other: any Equatable) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}

// MARK: - Internal free functions

/// Returns `true` if `lhs` and `rhs` are equal.
///
/// The most general overload: both parameters are untyped `Any`. Attempts to
/// cast each to `any Equatable` before delegating to
/// `areEqual(_ lhs: any Equatable, _ rhs: any Equatable)`. Returns `false`
/// if either value does not conform to `Equatable`.
///
/// Used by `useEffect` and `useCallback` to compare `UpdateStrategy.Dependency`
/// values stored as `Any` in the hook state array.
///
/// - Parameters:
///   - lhs: Left-hand value. Returns `false` if not `Equatable`.
///   - rhs: Right-hand value. Returns `false` if not `Equatable`.
internal func areEqual(_ lhs: Any,_ rhs: Any) -> Bool {
    guard
        let lhs = lhs as? any Equatable,
        let rhs = rhs as? any Equatable
    else { return false }

    return lhs.isEqual(rhs)
}

/// Returns `true` if `lhs` and `rhs` are equal.
///
/// Both parameters already conform to `Equatable`. Delegates to
/// `Equatable.isEqual(_:)` which handles cross-type comparison via
/// `isExactlyEqual`.
///
/// - Parameters:
///   - lhs: Left-hand `Equatable` value.
///   - rhs: Right-hand `Equatable` value.
internal func areEqual(_ lhs: any Equatable, _ rhs: any Equatable) -> Bool {
    lhs.isEqual(rhs)
}

/// Returns `true` if `lhs` and `rhs` are equal.
///
/// `Hashable`-constrained overload. Since `Hashable` refines `Equatable`,
/// this delegates directly to `Equatable.isEqual(_:)`. Provided as a
/// convenience to avoid ambiguity at call sites where the compiler resolves
/// both values to `any Hashable`.
///
/// - Parameters:
///   - lhs: Left-hand `Hashable` value.
///   - rhs: Right-hand `Hashable` value.
internal func areEqual(_ lhs: any Hashable, _ rhs: any Hashable) -> Bool {
    lhs.isEqual(rhs)
}
