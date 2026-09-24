import Testing
import StateKitCache

@Suite("SKAsyncCache — Polish Pass", .serialized)
struct AsyncCacheTests {

    @Test("set and get round-trip")
    func roundTrip() async {
        let cache = SKAsyncCache<String, Int>()
        await cache.set("a", 1)
        #expect(await cache.get("a") == 1)
    }

    @Test("capacity bounds size with LRU eviction")
    func capacityEviction() async {
        let cache = SKAsyncCache<String, Int>(capacity: 2)

        await cache.set("a", 1)
        await cache.set("b", 2)
        await cache.get("a") // refresh "a"
        await cache.set("c", 3) // evicts "b" (least recently used)

        #expect(await cache.get("a") == 1)
        #expect(await cache.get("b") == nil)
        #expect(await cache.get("c") == 3)
        #expect(await cache.count == 2)
    }

    @Test("TTL entries expire after the interval")
    func ttlExpiry() async {
        let cache = SKAsyncCache<String, Int>(ttl: 0.05)

        await cache.set("k", 9)
        #expect(await cache.get("k") == 9)

        try? await Task.sleep(nanoseconds: 150_000_000)
        #expect(await cache.get("k") == nil, "expired entry must be evicted")
    }

    @Test("concurrent multi-task access stays bounded and race-free")
    func concurrentAccess() async {
        let cache = SKAsyncCache<Int, Int>(capacity: 10)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<500 {
                group.addTask {
                    await cache.set(i, i * 2)
                    _ = await cache.get(i % 20)
                }
            }
        }

        let size = await cache.count
        #expect(size <= 10, "capacity must bound the cache (got \(size))")
    }

    @Test("remove and removeAll clear entries")
    func removal() async {
        let cache = SKAsyncCache<String, Int>()
        await cache.set("x", 1)
        await cache.set("y", 2)

        await cache.remove("x")
        #expect(await cache.get("x") == nil)

        await cache.removeAll()
        #expect(await cache.get("y") == nil)
        #expect(await cache.count == 0)
    }
}
