import Testing
import StateKitCache
import Foundation

// Spec 012 US2: TTL expiry reports through onExpire ONLY — onEvict stays reserved
// for capacity pressure and manual removal. (Contract previously reported as broken;
// verified correct in code — this suite pins it so it cannot regress silently.)

@MainActor
@Suite("TTL expiry — callback routing")
struct TTLCallbackRoutingTests {

    @Test("expired entry reports through onExpire only")
    func expiryReportsOnceThroughExpireCallback() async throws {
        let recorder = EventRecorder()

        let cache = TTLCache<String, Int>(
            ttl: 0.05,
            onEvict: { key, _, reason in
                recorder.record(key: key, reason: reason)
            },
            onExpire: { key, _ in
                recorder.record(key: key, reason: nil)
            }
        )

        cache.set("gone", 1, ttl: 0.05)
        cache.set("stays", 2, ttl: 60)

        // Past the short TTL.
        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(cache.get("gone") == nil, "expired entry must read as miss")
        #expect(cache.get("stays") == 2, "live entry must still read")

        let events = recorder.snapshot().filter { $0.key == "gone" }
        #expect(events.count == 1, "one expiry event, exactly one callback (got \(events.count))")
        #expect(events.first?.reason == nil, "expiry must route through onExpire, not onEvict")
    }

    @Test("manual removal still reports through onEvict")
    func manualRemoveReportsThroughEvictCallback() {
        let recorder = EventRecorder()

        let cache = TTLCache<String, Int>(
            ttl: 60,
            onEvict: { _, _, reason in
                recorder.record(key: "", reason: reason)
            },
            onExpire: { _, _ in
                recorder.record(key: "", reason: nil)
            }
        )

        cache.set("k", 1, ttl: 60)
        cache.remove("k")

        let events = recorder.snapshot()
        #expect(events.count == 1, "manual removal fires exactly one callback (got \(events.count))")
        #expect(events.first?.reason == .manual, "manual removal must fire onEvict(.manual)")
    }
}

/// Lock-protected (key, reason) recorder — evict callbacks may fire on any thread.
private final class EventRecorder: @unchecked Sendable {
    struct Event: Equatable {
        let key: String
        let reason: EvictionReason?
    }

    private let lock = NSLock()
    private var events: [Event] = []

    func record(key: String, reason: EvictionReason?) {
        lock.lock()
        events.append(Event(key: key, reason: reason))
        lock.unlock()
    }

    func snapshot() -> [Event] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}
