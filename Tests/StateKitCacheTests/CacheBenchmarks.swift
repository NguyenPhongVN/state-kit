import XCTest
import StateKitCache
import Foundation

/// Spec 014 US3: performance baselines for the cache hot paths.
/// These are advisory baselines (machine-dependent) — regressions are visible by
/// comparing output between runs; see docs/engineering/PERFORMANCE.md.
@MainActor
final class CacheBenchmarks: XCTestCase {

    func testLRUMixedOps() {
        let cache = LeastRecentlyUsedCache<Int, Int>(capacity: 10_000)
        measure {
            for i in 0..<10_000 {
                cache.set(i, i)
                _ = cache.get(i % 500)
            }
        }
    }

    func testTTLSetGet() {
        let cache = TTLCache<Int, Int>(ttl: 300)
        measure {
            for i in 0..<10_000 {
                cache.set(i, i, ttl: 300)
                _ = cache.get(i)
            }
        }
    }
}
