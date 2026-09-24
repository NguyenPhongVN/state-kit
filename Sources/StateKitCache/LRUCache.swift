import Foundation

// MARK: - LRU Cache

/// Least Recently Used cache that evicts the least recently accessed item when capacity is exceeded.
///
/// Bookkeeping is O(1) per operation: a dictionary for lookup plus a doubly
/// linked list for recency order (head = most recent, tail = least recent).
///
/// **Usage:**
/// ```swift
/// let cache = LeastRecentlyUsedCache<String, Data>(capacity: 100)
/// cache.set("key1", data1)
/// if let data = cache.get("key1") { }
/// ```
@MainActor
public final class LeastRecentlyUsedCache<Key: Hashable & Sendable, Value: Sendable>: @preconcurrency CacheProtocol, Sendable {

    /// One linked-list cell; also stored in `cache` for O(1) lookup.
    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    private var cache: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
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
        guard let node = cache[key] else {
            misses += 1
            return nil
        }
        moveToMostRecent(node)
        hits += 1
        return node.value
    }

    /// Stores value in cache.
    public func set(_ key: Key, _ value: Value) {
        if let node = cache[key] {
            node.value = value
            moveToMostRecent(node)
            return
        }

        let node = Node(key: key, value: value)
        cache[key] = node
        pushMostRecent(node)

        // Evict LRU if over capacity
        while cache.count > capacity, let lru = tail {
            unlink(lru)
            cache.removeValue(forKey: lru.key)
            onEvict?(lru.key, lru.value, .capacityExceeded)
        }
    }

    /// Removes value from cache.
    public func remove(_ key: Key) {
        guard let node = cache.removeValue(forKey: key) else { return }
        unlink(node)
        onEvict?(node.key, node.value, .manual)
    }

    /// Clears all cached values.
    public func clear() {
        cache.removeAll()
        head = nil
        tail = nil
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

    /// All keys in access order (least recently used first).
    public var keys: [Key] {
        var result: [Key] = []
        var node = tail
        while let current = node {
            result.append(current.key)
            node = current.prev
        }
        return result
    }

    /// Preloads multiple values.
    public func preload(_ items: [(key: Key, value: Value)]) {
        for (key, value) in items {
            set(key, value)
        }
    }

    // MARK: - Linked list internals

    private func pushMostRecent(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }

    private func unlink(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if head === node { head = node.next }
        if tail === node { tail = node.prev }
        node.prev = nil
        node.next = nil
    }

    private func moveToMostRecent(_ node: Node) {
        guard head !== node else { return }
        unlink(node)
        pushMostRecent(node)
    }
}

// MARK: - LRU Cache with Frequency Tracking

/// LFU variant: Least Frequently Used eviction.
@MainActor
public final class LeastFrequentlyUsedCache<Key: Hashable & Sendable, Value: Sendable>: @preconcurrency CacheProtocol, Sendable {
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
