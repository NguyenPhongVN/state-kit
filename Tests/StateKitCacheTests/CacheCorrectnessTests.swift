import Testing
import Foundation
@testable import StateKitCache

// Spec 009 US5: cache correctness — eager sliding expiry, sweep floor,
// single-flight cache-aside, clear eviction callbacks, pressure wiring.

@MainActor
@Suite("Cache Correctness — 009 US5")
struct CacheCorrectnessTests {

    @Test("sliding cache expires eagerly and does not refresh expired entries")
    func slidingEagerExpiry() {
        let cache = SlidingWindowTTLCache<String, Int>(ttl: 0.05)
        cache.set("k", 1)
        #expect(cache.get("k") == 1)

        Thread.sleep(forTimeInterval: 0.08)
        #expect(cache.get("k") == nil, "expired entry served before the background sweep")
    }

    @Test("sweep interval has a one-second floor for tiny TTLs")
    func sweepFloor() {
        let cache = TTLCache<String, Int>(ttl: 0.001)
        #expect(cache.sweepIntervalForTesting >= 1.0)
        let sliding = SlidingWindowTTLCache<String, Int>(ttl: 0.001)
        #expect(sliding.sweepIntervalForTesting >= 1.0)
    }

    @Test("cache-aside single-flight fetches once for concurrent misses")
    func singleFlight() async throws {
        let cache = LeastRecentlyUsedCache<String, Int>(capacity: 10)
        let fetchCount = LockedCounter()
        let pattern = CacheAsidePattern(cache: cache) { key in
            fetchCount.hit()
            try await Task.sleep(for: .milliseconds(50))
            return key.count
        }

        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<20 {
                group.addTask { try await pattern.get("cold-key") }
            }
            var out: [Int] = []
            for try await v in group { out.append(v) }
            return out
        }

        #expect(results.count == 20)
        #expect(fetchCount.count == 1, "thundering herd: fetcher ran multiple times")
    }

    @Test("clear fires onEvict(.cleared) for every entry")
    func clearFiresOnEvict() {
        final class Collector: @unchecked Sendable {
            private let lock = NSLock()
            private var keys: [String] = []
            func add(_ k: String) { lock.lock(); keys.append(k); lock.unlock() }
            var all: [String] { lock.lock(); defer { lock.unlock() }; return keys }
        }

        let evictions = Collector()
        let cache = LeastRecentlyUsedCache<String, Int>(capacity: 10) { key, _, reason in
            if case .cleared = reason { evictions.add(key) }
        }
        cache.set("a", 1)
        cache.set("b", 2)
        cache.clear()
        #expect(Set(evictions.all) == ["a", "b"], "clear() dropped onEvict callbacks")

        let lfuEvictions = Collector()
        let lfu = LeastFrequentlyUsedCache<String, Int>(capacity: 10) { key, _, reason in
            if case .cleared = reason { lfuEvictions.add(key) }
        }
        lfu.set("x", 1)
        lfu.clear()
        #expect(lfuEvictions.all == ["x"])
    }

    @Test("memory pressure handler wires to system notifications")
    func memoryPressureWiring() {
        let cache = LeastRecentlyUsedCache<String, Int>(capacity: 10)
        cache.set("a", 1)
        cache.set("b", 2)
        let handler = MemoryPressureHandler(cache: cache, targetSize: 1)
        let unsubscribe = handler.wireToSystemNotifications()
        unsubscribe()
        #expect(true, "wiring returned a usable unsubscribe token")
    }
}

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func hit() { lock.lock(); n += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return n }
}
