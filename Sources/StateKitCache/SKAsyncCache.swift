import Foundation

/// An actor-isolated, race-free key-value cache usable from **any isolation
/// domain** — unlike the MainActor-only `LeastRecentlyUsedCache`/
/// `TimeToLiveCache` family.
///
/// Optional behaviors:
/// - **Capacity** — when set, eviction is least-recently-used (O(1) refresh
///   on `get`).
/// - **TTL** — when set, entries expire lazily: expired entries are dropped
///   on access and swept during writes.
///
/// ```swift
/// let cache = SKAsyncCache<String, Data>(capacity: 200, ttl: 300)
/// let entry = await cache.get("avatar:42")
/// ```
public actor SKAsyncCache<Key: Hashable & Sendable, Value: Sendable> {

    private struct Entry {
        var value: Value
        var expiresAt: Date?
        var lastAccess: Int
    }

    private var entries: [Key: Entry] = [:]
    private var accessCounter = 0
    private let capacity: Int?
    private let ttl: TimeInterval?

    /// Creates an async cache.
    ///
    /// - Parameters:
    ///   - capacity: Maximum entries before least-recently-used eviction.
    ///     `nil` = unbounded.
    ///   - ttl: Seconds an entry stays valid. `nil` = no expiry.
    public init(capacity: Int? = nil, ttl: TimeInterval? = nil) {
        self.capacity = capacity.map { max(1, $0) }
        self.ttl = ttl
    }

    /// Returns the value for `key`, or `nil` if missing or expired.
    public func get(_ key: Key) -> Value? {
        guard var entry = entries[key] else { return nil }
        if let expiresAt = entry.expiresAt, Date() >= expiresAt {
            entries.removeValue(forKey: key)
            return nil
        }
        accessCounter += 1
        entry.lastAccess = accessCounter
        entries[key] = entry
        return entry.value
    }

    /// Stores `value` for `key`, then sweeps capacity + expired entries.
    public func set(_ key: Key, _ value: Value) {
        sweepExpired()
        accessCounter += 1
        entries[key] = Entry(value: value, expiresAt: ttl.map { Date().addingTimeInterval($0) },
                             lastAccess: accessCounter)
        evictOverCapacity()
    }

    /// Removes the entry for `key`, if present.
    public func remove(_ key: Key) {
        entries.removeValue(forKey: key)
    }

    /// Removes every entry.
    public func removeAll() {
        entries.removeAll()
    }

    /// The number of stored entries (including not-yet-swept expired ones).
    public var count: Int {
        entries.count
    }

    // MARK: - Internals

    private func evictOverCapacity() {
        guard let capacity, entries.count > capacity else { return }
        let lru = entries
            .sorted { ($0.value.lastAccess, $1.key.hashValue) < ($1.value.lastAccess, $0.key.hashValue) }
            .prefix(entries.count - capacity)
        for (key, _) in lru {
            entries.removeValue(forKey: key)
        }
    }

    private func sweepExpired() {
        guard ttl != nil else { return }
        let now = Date()
        for key in entries.keys where entries[key].map({ entry in
            entry.expiresAt.map { now >= $0 } ?? false
        }) == true {
            entries.removeValue(forKey: key)
        }
    }
}
