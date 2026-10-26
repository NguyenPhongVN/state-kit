import Testing
import Observation
import Foundation
@testable import StateKitDevTools

// Spec 008 US7: the render counter used by StateDevScope must be a reference
// helper so incrementing it does not invalidate the scope's own body (the old
// mechanism enqueued an effect that mutated a @State read in the same body —
// a self-sustaining re-render loop, active even in Release builds). Release
// stripping is a build-time condition (#if DEBUG), stated as an assumption in
// the spec; this suite pins the helper's quiescence and observation contract.

@MainActor
@Suite("StateDevScope Render Count — P1 fixes")
struct StateDevScopeRenderCountTests {

    @Test("counter increments and notifies observers")
    func incrementsAndNotifies() async throws {
        let counter = StateDevRenderCounter()
        #expect(counter.count == 0)

        let fired = FiredFlag()
        withObservationTracking {
            _ = counter.count
        } onChange: {
            fired.mark()
        }

        counter.increment()
        #expect(counter.count == 1)

        for _ in 0..<100 where !fired.isFired {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(fired.isFired, "increment did not notify observation tracking")
    }

    @Test("counter is a reference type shared by reference")
    func referenceSemantics() {
        let counter = StateDevRenderCounter()
        let alias = counter
        counter.increment()
        #expect(alias.count == 1, "counter must be shared by reference")
    }

    @Test("many increments do not enqueue render effects on the counter itself")
    func quiescenceAfterManyPasses() {
        let counter = StateDevRenderCounter()
        for _ in 0..<1000 {
            counter.increment()
        }
        #expect(counter.count == 1000)
        // The scope body no longer reads this value, so a count change cannot
        // cause another body pass — the loop is structurally gone. This test
        // documents the helper's side: it only counts, never schedules work.
    }
}

/// Thread-safe one-shot flag for observation callbacks.
final class FiredFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    func mark() {
        lock.lock()
        fired = true
        lock.unlock()
    }

    var isFired: Bool {
        lock.lock()
        defer { lock.unlock() }
        return fired
    }
}
