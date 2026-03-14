// ============================================================
// MARK: - Revision
// ============================================================

struct Revision: Hashable, Comparable, Sendable {

    let value: UInt64

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.value < rhs.value
    }
}
