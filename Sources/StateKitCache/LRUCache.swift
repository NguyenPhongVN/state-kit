import Foundation

// MARK: - LRU Cache

/// Least Recently Used cache that evicts the least recently accessed item when capacity is exceeded.
///
/// **Usage:**
/// ```swift
/// let cache = LeastRecentlyUsedCache<String, Data>(capacity: 100)
/// cache.set("key1", data1)
/// if let data = cache.get("key1") { }
/// ```
@MainActor
public final class LeastRecentlyUsedCache<Key: Hashable & Sendable, Value: Sendable>: CacheProtocol, Sendable {
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private var hits = 0
    private var misses = 0
    private let capacity: Int
    private var onEvict: CacheEvictionCallback<Key, Value>?

    /// Creates LRU cache with capacity.
    public init(capacity: Int = 100, onEvict: CacheEvictionCallback<Key, Value>? = nil) {
        self.capacity = max(1, capacity)
        self.onEvict = onEvict
    }

    /// Retrieves value from cache (marks as recently used).
    public func get(_ key: Key) -> Value? {
        if let value = cache[key] {
            // Move to end (most recently used)
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            hits += 1
            return value
        }

        misses += 1
        return nil
    }

    /// Stores value in cache.
    public func set(_ key: Key, _ value: Value) {
        // Remove if exists
        if cache[key] != nil {
            accessOrder.removeAll { $0 == key }
        }

        // Add value
        cache[key] = value
        accessOrder.append(key)

        // Evict LRU if over capacity
        while cache.count > capacity, let lru = accessOrder.first {
            cache.removeValue(forKey: lru)
            accessOrder.removeFirst()
            if let value = cache[lru] {
                onEvict?(lru, value, .capacityExceeded)
            }
        }
    }

    /// Removes value from cache.
    public func remove(_ key: Key) {
        if let value = cache.removeValue(forKey: key) {
            accessOrder.removeAll { $0 == key }
            onEvict?(key, value, .manual)
        }
    }

    /// Clears all cached values.
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    /// Cache statistics.
    public var stats: CacheStats {
        CacheStats(hits: hits, misses: misses, size: cache.count, capacity: capacity)
    }

    /// Resets statistics.
    public func resetStats() {
        hits = 0
        misses = 0
    }

    /// Number of items in cache.
    public var count: Int {
        cache.count
    }

    /// All keys in access order.
    public var keys: [Key] {
        accessOrder
    }

    /// Preloads multiple values.
    public func preload(_ items: [(key: Key, value: Value)]) {
        for (key, value) in items {
            set(key, value)
        }
    }
}

// MARK: - LRU Cache with Frequency Tracking

/// LFU variant: Least Frequently Used eviction.
@MainActor
public final class LeastFrequentlyUsedCache<Key: Hashable & Sendable, Value: Sendable>: CacheProtocol, Sendable {
    private var cache: [Key: Value] = [:]
    private var frequency: [Key: Int] = [:]
    private var hits = 0
    private var misses = 0
    private let capacity: Int
    private var onEvict: CacheEvictionCallback<Key, Value>?

    /// Creates LFU cache with capacity.
    public init(capacity: Int = 100, onEvict: CacheEvictionCallback<Key, Value>? = nil) {
        self.capacity = max(1, capacity)
        self.onEvict = onEvict
    }

    /// Retrieves value (increments frequency).
    public func get(_ key: Key) -> Value? {
        if let value = cache[key] {
            frequency[key] = (frequency[key] ?? 0) + 1
            hits += 1
            return value
        }

        misses += 1
        return nil
    }

    /// Stores value.
    public func set(_ key: Key, _ value: Value) {
        if cache[key] == nil {
            // Evict LFU if over capacity
            while cache.count >= capacity, let lfu = frequency.min(by: { $0.value < $1.value })?.key {
                if let evicted = cache.removeValue(forKey: lfu) {
                    frequency.removeValue(forKey: lfu)
                    onEvict?(lfu, evicted, .capacityExceeded)
                }
            }
        }

        cache[key] = value
        frequency[key] = (frequency[key] ?? 0) + 1
    }

    /// Removes value.
    public func remove(_ key: Key) {
        if let value = cache.removeValue(forKey: key) {
            frequency.removeValue(forKey: key)
            onEvict?(key, value, .manual)
        }
    }

    /// Clears all.
    public func clear() {
        cache.removeAll()
        frequency.removeAll()
    }

    /// Statistics.
    public var stats: CacheStats {
        CacheStats(hits: hits, misses: misses, size: cache.count, capacity: capacity)
    }

    /// Resets stats.
    public func resetStats() {
        hits = 0
        misses = 0
    }

    /// Count.
    public var count: Int {
        cache.count
    }
}
