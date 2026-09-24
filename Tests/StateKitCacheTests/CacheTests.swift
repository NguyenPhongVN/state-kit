import XCTest
import StateKitCache

@MainActor
final class CacheTests: XCTestCase {
    // MARK: - LRU Cache Tests

    func testLRUEvictionOrder() {
        let cache = LeastRecentlyUsedCache<String, Int>(capacity: 3)

        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("c", 3)
        cache.set("d", 4)  // Evicts "a" (least recently used)

        XCTAssertNil(cache.get("a"))
        XCTAssertEqual(cache.get("b"), 2)
        XCTAssertEqual(cache.get("c"), 3)
        XCTAssertEqual(cache.get("d"), 4)
    }

    func testLRUAccessUpdatesOrder() {
        let cache = LeastRecentlyUsedCache<String, Int>(capacity: 2)

        cache.set("a", 1)
        cache.set("b", 2)
        _ = cache.get("a")  // Make "a" most recently used
        cache.set("c", 3)   // Evicts "b", not "a"

        XCTAssertEqual(cache.get("a"), 1)
        XCTAssertNil(cache.get("b"))
        XCTAssertEqual(cache.get("c"), 3)
    }

    func testLRUEvictionCallback() {
        var evictedKey: String?
        var evictedValue: String?

        let cache = LeastRecentlyUsedCache<String, String>(capacity: 2) { key, value, _ in
            evictedKey = key
            evictedValue = value
        }

        cache.set("a", "A")
        cache.set("b", "B")
        cache.set("c", "C")  // Evicts "a"

        XCTAssertEqual(evictedKey, "a")
        XCTAssertEqual(evictedValue, "A")
    }

    func testLRUStats() {
        let cache = LeastRecentlyUsedCache<String, Int>(capacity: 2)

        cache.set("a", 1)
        _ = cache.get("a")  // Hit
        _ = cache.get("b")  // Miss

        let stats = cache.stats
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.size, 1)
        XCTAssertEqual(stats.capacity, 2)
    }

    // MARK: - TTL Cache Tests

    func testTTLExpiration() async {
        let cache = TimeToLiveCache<String, String>(ttl: 0.1)

        cache.set("key", "value")
        XCTAssertEqual(cache.get("key"), "value")

        try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds

        XCTAssertNil(cache.get("key"))
    }

    func testTTLValidCount() async {
        let cache = TimeToLiveCache<String, String>(ttl: 0.1)

        cache.set("a", "A")
        cache.set("b", "B")
        XCTAssertEqual(cache.validCount, 2)

        try? await Task.sleep(nanoseconds: 150_000_000)  // 0.15 seconds

        XCTAssertEqual(cache.validCount, 0)
    }

    // MARK: - Cache-Aside Pattern Tests

    func testCacheAsidePattern() async throws {
        let cache = LeastRecentlyUsedCache<String, String>(capacity: 10)
        var fetchCount = 0

        let pattern = CacheAsidePattern(cache: cache) { key in
            fetchCount += 1
            return "value-\(key)"
        }

        let value1 = try await pattern.get("key1")
        XCTAssertEqual(value1, "value-key1")
        XCTAssertEqual(fetchCount, 1)

        let value2 = try await pattern.get("key1")  // Hit cache
        XCTAssertEqual(value2, "value-key1")
        XCTAssertEqual(fetchCount, 1)  // No additional fetch
    }

    // MARK: - LFU Cache Tests

    func testLFUEviction() {
        let cache = LeastFrequentlyUsedCache<String, Int>(capacity: 2)

        cache.set("a", 1)
        cache.set("b", 2)
        _ = cache.get("a")  // "a" frequency = 2
        _ = cache.get("a")  // "a" frequency = 3
        cache.set("c", 3)   // "b" evicted (frequency 1 < "a" frequency 3)

        XCTAssertEqual(cache.get("a"), 1)
        XCTAssertNil(cache.get("b"))
        XCTAssertEqual(cache.get("c"), 3)
    }

    // MARK: - Housekeeping Loop Lifetime (Leak Fix)

    private final class WeakTTLRef {
        weak var cache: TimeToLiveCache<String, Int>?
        init(_ cache: TimeToLiveCache<String, Int>) { self.cache = cache }
    }

    private final class WeakSlidingRef {
        weak var cache: SlidingWindowTTLCache<String, Int>?
        init(_ cache: SlidingWindowTTLCache<String, Int>) { self.cache = cache }
    }

    func testTimeToLiveCacheDeallocatesAfterRelease() async throws {
        weak var weakCache: TimeToLiveCache<String, Int>?
        var cache: TimeToLiveCache<String, Int>? = TimeToLiveCache(ttl: 60)
        weakCache = cache
        cache = nil

        for _ in 0..<50 { await Task.yield() }
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(weakCache, "TimeToLiveCache leaked: housekeeping task captures self strongly")
    }

    func testSlidingWindowCacheDeallocatesAfterRelease() async throws {
        weak var weakCache: SlidingWindowTTLCache<String, Int>?
        var cache: SlidingWindowTTLCache<String, Int>? = SlidingWindowTTLCache(ttl: 60)
        weakCache = cache
        cache = nil

        for _ in 0..<50 { await Task.yield() }
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(weakCache, "SlidingWindowTTLCache leaked: housekeeping task captures self strongly")
    }

    func testThousandTimeToLiveCachesDeallocate() {
        var refs: [WeakTTLRef] = []
        for _ in 0..<1_000 {
            refs.append(WeakTTLRef(TimeToLiveCache<String, Int>(ttl: 0.02)))
        }

        XCTAssertTrue(refs.allSatisfy { $0.cache == nil }, "1,000 instances must all deallocate after release")
    }

    func testTimeToLiveCacheStillExpiresWhileAlive() async throws {
        var expiredKeys: [String] = []
        let cache = TimeToLiveCache<String, Int>(ttl: 0.1) { key, _, _ in
            expiredKeys.append(key)
        }
        cache.set("k", 1)

        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNil(cache.get("k"), "entry must expire while the cache is alive")
        XCTAssertEqual(expiredKeys, ["k"], "background cleanup must still run for live instances")
    }

    func testSlidingWindowCacheStillExpiresWhileAlive() async throws {
        var expiredKeys: [String] = []
        let cache = SlidingWindowTTLCache<String, Int>(ttl: 0.1) { key, _, _ in
            expiredKeys.append(key)
        }
        cache.set("k", 1)

        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNil(cache.get("k"), "entry must expire while the cache is alive")
        XCTAssertEqual(expiredKeys, ["k"], "background cleanup must still run for live instances")
    }
}
