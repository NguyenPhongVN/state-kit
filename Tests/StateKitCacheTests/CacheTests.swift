import XCTest
import StateKitCache

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
        let cache = LeastRecentlyUsedCache<String, String>(capacity: 2)
        var evictedKey: String?
        var evictedValue: String?

        cache.onEvict = { key, value, _ in
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
}
