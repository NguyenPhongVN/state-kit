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
    // Mask the top bit before converting: on 32-bit targets `Int(hash)` traps
    // for values above Int32.max (64-bit targets are unaffected).
    return Int(hash & 0x7FFF_FFFF)
}
