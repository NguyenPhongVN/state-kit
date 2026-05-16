import Foundation

// MARK: - Shared Hash Utilities

/// DJB2 hash function for deterministic user assignment.
@usableFromInline
internal func djb2Hash(_ str: String) -> Int {
    var hash = 5381
    for char in str {
        hash = ((hash << 5) &+ hash) &+ Int(char.asciiValue ?? 0)
    }
    return abs(hash)
}
