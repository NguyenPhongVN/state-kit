import Foundation

// MARK: - TTL Cache

/// Time-To-Live cache that automatically expires entries after a specified duration.
///
/// **Usage:**
/// ```swift
/// let cache = TimeToLiveCache<String, Data>(ttl: 300)  // 5 minutes
/// cache.set("key1", data1)
/// if let data = cache.get("key1") { }  // Returns nil if expired
/// ```
@MainActor
public final class TimeToLiveCache<Key: Hashable & Sendable, Value: Sendable>: @MainActor CacheProtocol, Sendable {
    private struct Entry: Sendable {
        let value: Value
        let expiresAt: Date
    }

    private var cache: [Key: Entry] = [:]
    private var hits = 0
    private var misses = 0
    private let ttl: TimeInterval
    private var cleanupTask: Task<Void, Never>?
    private var onEvict: CacheEvictionCallback<Key, Value>?
    private var onExpire: ((Key, Value) -> Void)?

    /// Creates TTL cache with specified time-to-live duration.
    public init(
        ttl: TimeInterval = 300,
        onEvict: CacheEvictionCallback<Key, Value>? = nil,
        onExpire: ((Key, Value) -> Void)? = nil
    ) {
        self.ttl = max(1, ttl)
        self.onEvict = onEvict
        self.onExpire = onExpire
        startBackgroundCleanup()
    }

    deinit {
        cleanupTask?.cancel()
    }

    /// Retrieves value from cache.
    public func get(_ key: Key) -> Value? {
        if let entry = cache[key] {
            if Date() < entry.expiresAt {
                hits += 1
                return entry.value
            } else {
                // Expired
                cache.removeValue(forKey: key)
                onEvict?(key, entry.value, .expired)
                onExpire?(key, entry.value)
                misses += 1
                return nil
            }
        }

        misses += 1
        return nil
    }

    /// Stores value in cache.
    public func set(_ key: Key, _ value: Value) {
        let expiresAt = Date().addingTimeInterval(ttl)
        cache[key] = Entry(value: value, expiresAt: expiresAt)
    }

    /// Removes value from cache.
    public func remove(_ key: Key) {
        if let entry = cache.removeValue(forKey: key) {
            onEvict?(key, entry.value, .manual)
        }
    }

    /// Clears all cached values.
    public func clear() {
        cache.removeAll()
    }

    /// Cache statistics.
    public var stats: CacheStats {
        CacheStats(hits: hits, misses: misses, size: cache.count, capacity: .max)
    }

    /// Resets statistics.
    public func resetStats() {
        hits = 0
        misses = 0
    }

    /// Number of items in cache (including expired).
    public var count: Int {
        cache.count
    }

    /// Number of non-expired items.
    public var validCount: Int {
        let now = Date()
        return cache.values.filter { $0.expiresAt > now }.count
    }

    /// Sets custom TTL for specific key.
    public func set(_ key: Key, _ value: Value, ttl customTTL: TimeInterval) {
        let expiresAt = Date().addingTimeInterval(customTTL)
        cache[key] = Entry(value: value, expiresAt: expiresAt)
    }

    /// Manually triggers cleanup of expired entries.
    public func cleanup() {
        let now = Date()
        var expired: [Key] = []

        for (key, entry) in cache {
            if entry.expiresAt <= now {
                expired.append(key)
            }
        }

        for key in expired {
            if let entry = cache.removeValue(forKey: key) {
                onEvict?(key, entry.value, .expired)
                onExpire?(key, entry.value)
            }
        }
    }

    // MARK: - Background Cleanup

    private func startBackgroundCleanup() {
        cleanupTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(ttl * 1_000_000_000 / 2))  // Cleanup every half TTL

                if !Task.isCancelled {
                    cleanup()
                }
            }
        }
    }
}

// MARK: - Sliding Window Cache

/// TTL cache with sliding window: TTL resets on access.
@MainActor
public final class SlidingWindowTTLCache<Key: Hashable & Sendable, Value: Sendable>: @MainActor CacheProtocol, Sendable {
    private struct Entry: Sendable {
        let value: Value
        var lastAccessedAt: Date
        let createdAt: Date
    }

    private var cache: [Key: Entry] = [:]
    private var hits = 0
    private var misses = 0
    private let ttl: TimeInterval
    private var onEvict: CacheEvictionCallback<Key, Value>?
    private var cleanupTask: Task<Void, Never>?

    /// Creates sliding window TTL cache.
    public init(ttl: TimeInterval = 300, onEvict: CacheEvictionCallback<Key, Value>? = nil) {
        self.ttl = max(1, ttl)
        self.onEvict = onEvict
        startBackgroundCleanup()
    }

    deinit {
        cleanupTask?.cancel()
    }

    /// Retrieves value and resets TTL.
    public func get(_ key: Key) -> Value? {
        if var entry = cache[key] {
            entry.lastAccessedAt = Date()
            cache[key] = entry
            hits += 1
            return entry.value
        }

        misses += 1
        return nil
    }

    /// Stores value.
    public func set(_ key: Key, _ value: Value) {
        let now = Date()
        cache[key] = Entry(value: value, lastAccessedAt: now, createdAt: now)
    }

    /// Removes value.
    public func remove(_ key: Key) {
        if let entry = cache.removeValue(forKey: key) {
            onEvict?(key, entry.value, .manual)
        }
    }

    /// Clears all.
    public func clear() {
        cache.removeAll()
    }

    /// Statistics.
    public var stats: CacheStats {
        CacheStats(hits: hits, misses: misses, size: cache.count, capacity: .max)
    }

    /// Resets stats.
    public func resetStats() {
        hits = 0
        misses = 0
    }

    /// Expires old entries.
    public func cleanup() {
        let now = Date()
        var expired: [Key] = []

        for (key, entry) in cache {
            if now.timeIntervalSince(entry.lastAccessedAt) > ttl {
                expired.append(key)
            }
        }

        for key in expired {
            if let entry = cache.removeValue(forKey: key) {
                onEvict?(key, entry.value, .expired)
            }
        }
    }

    // MARK: - Background Cleanup

    private func startBackgroundCleanup() {
        cleanupTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(ttl * 1_000_000_000 / 2))  // Cleanup every half TTL

                if !Task.isCancelled {
                    cleanup()
                }
            }
        }
    }
}
