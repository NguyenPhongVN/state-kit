import Foundation
import Riverpods

// MARK: - Cache Policies

/// Cache-aside pattern helper.
@MainActor
public struct CacheAsidePattern<Key: Hashable & Sendable, Value: Sendable> {
    private let cache: LeastRecentlyUsedCache<Key, Value>
    private let fetcher: (Key) async throws -> Value

    public init(cache: LeastRecentlyUsedCache<Key, Value>, fetcher: @escaping (Key) async throws -> Value) {
        self.cache = cache
        self.fetcher = fetcher
    }

    /// Gets value from cache or fetches if missing.
    public func get(_ key: Key) async throws -> Value {
        if let cached = cache.get(key) {
            return cached
        }

        let value = try await fetcher(key)
        cache.set(key, value)
        return value
    }
}

/// Write-through pattern: writes to both cache and storage.
@MainActor
public struct WriteThroughPattern<Key: Hashable & Sendable, Value: Sendable> {
    private let cache: LeastRecentlyUsedCache<Key, Value>
    private let writer: (Key, Value) async throws -> Void

    public init(cache: LeastRecentlyUsedCache<Key, Value>, writer: @escaping (Key, Value) async throws -> Void) {
        self.cache = cache
        self.writer = writer
    }

    /// Sets value in both cache and storage.
    public func set(_ key: Key, _ value: Value) async throws {
        cache.set(key, value)
        try await writer(key, value)
    }
}

// MARK: - Cache Provider Factory

/// Factory for creating provider-based caches.
public struct CacheProviderFactory {
    /// Creates a provider that uses cache-aside pattern.
    @MainActor
    public static func cacheAside<Key: Hashable & Sendable, T: Sendable>(
        key: Key,
        capacity: Int = 100,
        fetcher: @escaping (Key) async throws -> T
    ) -> FutureProvider<T> {
        let cache = LeastRecentlyUsedCache<Key, T>(capacity: capacity)

        return FutureProvider { ref in
            if let cached = cache.get(key) {
                return cached
            }

            let value = try await fetcher(key)
            cache.set(key, value)
            return value
        }
    }

    /// Creates family provider with caching.
    @MainActor
    public static func cachedFamily<Key: Hashable & Sendable, T: Sendable>(
        capacity: Int = 100,
        fetcher: @escaping (Key) async throws -> T
    ) -> (Key) -> FutureProvider<T> {
        let cache = LeastRecentlyUsedCache<Key, T>(capacity: capacity)

        return FutureProvider.family { (ref, key: Key) in
            if let cached = cache.get(key) {
                return cached
            }

            let value = try await fetcher(key)
            cache.set(key, value)
            return value
        }
    }
}

// MARK: - Memory Pressure Handling

/// Handles memory pressure by clearing cache.
@MainActor
public struct MemoryPressureHandler<Key: Hashable & Sendable, Value: Sendable> {
    private let cache: LeastRecentlyUsedCache<Key, Value>
    private let targetSize: Int

    public init(cache: LeastRecentlyUsedCache<Key, Value>, targetSize: Int = 10) {
        self.cache = cache
        self.targetSize = targetSize
    }

    /// Handles memory pressure by trimming cache to target size.
    /// Removes oldest items first (LRU eviction policy).
    public func handleMemoryPressure() {
        // Remove oldest items until we reach target size
        let keys = cache.keys
        let itemsToRemove = max(0, keys.count - targetSize)

        for i in 0..<itemsToRemove {
            if i < keys.count {
                cache.remove(keys[i])
            }
        }
    }
}

// MARK: - Cache Preloading

/// Preloads cache with values.
@MainActor
public struct CachePreloader<Key: Hashable & Sendable, Value: Sendable> {
    private let cache: LeastRecentlyUsedCache<Key, Value>

    public init(cache: LeastRecentlyUsedCache<Key, Value>) {
        self.cache = cache
    }

    /// Preloads cache with items.
    public func preload(_ items: [(key: Key, value: Value)]) {
        cache.preload(items)
    }

    /// Preloads from async source.
    public func preloadAsync(_ fetcher: () async throws -> [(Key, Value)]) async throws {
        let items = try await fetcher()
        preload(items)
    }
}

// MARK: - Cache Warming

/// Warms cache with initial data.
@MainActor
public struct CacheWarmer<Key: Hashable & Sendable, Value: Sendable> {
    private let cache: LeastRecentlyUsedCache<Key, Value>

    public init(cache: LeastRecentlyUsedCache<Key, Value>) {
        self.cache = cache
    }

    /// Warms cache on app startup.
    public func warmCache(with keys: [Key], fetcher: (Key) async throws -> Value) async throws {
        for key in keys {
            let value = try await fetcher(key)
            cache.set(key, value)
        }
    }
}

// MARK: - Cache Invalidation

/// Invalidation strategies for cache entries.
public enum CacheInvalidationStrategy {
    case immediate              // Invalidate immediately
    case debounced(TimeInterval)  // Invalidate after delay
    case batch(Int)            // Invalidate in batches

    @MainActor
    public func apply<K: Hashable & Sendable, V: Sendable>(
        to cache: LeastRecentlyUsedCache<K, V>,
        invalidate key: K
    ) async {
        switch self {
        case .immediate:
            cache.remove(key)

        case .debounced(let delay):
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                cache.remove(key)
            }

        case .batch:
            // Would batch multiple invalidations
            cache.remove(key)
        }
    }
}

// MARK: - Cache Monitoring

/// Monitors cache performance.
@MainActor
public struct CacheMonitor<Key: Hashable & Sendable, Value: Sendable> {
    private let cache: LeastRecentlyUsedCache<Key, Value>

    public init(cache: LeastRecentlyUsedCache<Key, Value>) {
        self.cache = cache
    }

    /// Gets performance report.
    public func report() -> String {
        let stats = cache.stats
        return """
        Cache Performance Report
        =======================
        Hits: \(stats.hits)
        Misses: \(stats.misses)
        Hit Rate: \(String(format: "%.1f", stats.hitRate * 100))%
        Size: \(stats.size)/\(stats.capacity)
        """
    }

    /// Checks if cache is healthy.
    public func isHealthy(minHitRate: Double = 0.7) -> Bool {
        cache.stats.hitRate >= minHitRate
    }
}
