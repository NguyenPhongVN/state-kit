import Foundation

// MARK: - Type-Erased Equality Helpers

/// Type-erased equality via a casting anchor: compares `self` to another
/// `any Equatable` only when it is exactly the same concrete type.
extension Equatable {
    /// Returns `true` when `other` is the same concrete type and equal.
    fileprivate func isEqual(_ other: any Equatable) -> Bool {
        isExactlyEqual(other)
    }

    /// The cast anchor for the cross-type comparison.
    private func isExactlyEqual(_ other: any Equatable) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}

/// Returns `true` if `lhs` and `rhs` are equal (both castable to `any Equatable`).
///
/// Used by `useEffect` and `useCallback` to compare `UpdateStrategy.Dependency`
/// values stored as `Any` in the hook state array.
internal func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    guard
        let lhs = lhs as? any Equatable,
        let rhs = rhs as? any Equatable
    else { return false }

    return lhs.isEqual(rhs)
}

/// Returns `true` if `lhs` and `rhs` are equal (both `any Equatable`).
internal func areEqual(_ lhs: any Equatable, _ rhs: any Equatable) -> Bool {
    lhs.isEqual(rhs)
}

/// Returns `true` if `lhs` and `rhs` are equal (both `any Hashable`).
internal func areEqual(_ lhs: any Hashable, _ rhs: any Hashable) -> Bool {
    lhs.isEqual(rhs)
}
