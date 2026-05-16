import Foundation

// MARK: - StateKit Cache Module

/// StateKitCache provides advanced caching strategies for StateKit applications.
///
/// Includes:
/// - LRU (Least Recently Used) caching with configurable capacity
/// - TTL (Time-To-Live) caching with automatic expiry
/// - Pluggable cache policies
/// - Cache-aside pattern helpers
///
/// All caches are thread-safe and integrate with StateKit's state management.

public enum StateKitCache {
    public static let version = "2.6.0-beta"
}

// MARK: - Cache Protocol

/// Protocol for cache implementations.
public protocol CacheProtocol<Key, Value>: Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable

    /// Retrieves value from cache.
    func get(_ key: Key) -> Value?

    /// Stores value in cache.
    func set(_ key: Key, _ value: Value)

    /// Removes value from cache.
    func remove(_ key: Key)

    /// Clears all cached values.
    func clear()

    /// Gets cache statistics.
    var stats: CacheStats { get }
}

// MARK: - Cache Statistics

/// Statistics about cache performance.
public struct CacheStats: Sendable {
    public let hits: Int
    public let misses: Int
    public let size: Int
    public let capacity: Int

    public var hitRate: Double {
        let total = Double(hits + misses)
        return total > 0 ? Double(hits) / total : 0
    }

    public init(hits: Int = 0, misses: Int = 0, size: Int = 0, capacity: Int = 0) {
        self.hits = hits
        self.misses = misses
        self.size = size
        self.capacity = capacity
    }
}

// MARK: - Cache Eviction Callback

/// Callback when item is evicted from cache.
public typealias CacheEvictionCallback<Key: Hashable, Value> = (Key, Value, EvictionReason) -> Void

/// Reason for cache eviction.
public enum EvictionReason: String, Sendable {
    case capacityExceeded  // LRU/LFU evicted
    case expired           // TTL expired
    case manual            // Manually removed
    case cleared           // Cache cleared
}

// Re-export main cache types
public typealias LRUCache = LeastRecentlyUsedCache
public typealias TTLCache = TimeToLiveCache
