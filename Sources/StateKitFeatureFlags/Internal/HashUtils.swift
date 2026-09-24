import Foundation

// MARK: - Shared Hash Utilities

/// DJB2 hash function for deterministic user assignment.
///
/// Hashes the string's UTF-8 bytes so every character participates
/// regardless of script (the previous `asciiValue ?? 0` approach reduced all
/// non-ASCII characters to 0, collapsing distinct international user IDs onto
/// the same rollout bucket). Unsigned 32-bit arithmetic keeps the result
/// non-negative without `abs()`, which also removes the `abs(Int.min)` trap.
@usableFromInline
internal func djb2Hash(_ str: String) -> Int {
    var hash: UInt32 = 5381
    for byte in str.utf8 {
        hash = (hash &* 33) &+ UInt32(byte)
    }
    return Int(hash)
}
