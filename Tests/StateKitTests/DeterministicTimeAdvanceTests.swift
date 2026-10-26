import Testing
import Foundation
import StateKitTesting

// Spec 008 US10: DeterministicTimeProvider.advance(by:) must mutate the
// current time (previously the addTimeInterval result was discarded — a no-op
// that made time-stepping tests pass vacuously).

@Suite("DeterministicTime Advance — P1 fixes")
struct DeterministicTimeAdvanceTests {

    @Test("advance moves time forward by the interval")
    func advancesForward() {
        let start = Date(timeIntervalSince1970: 1_000)
        var provider = DeterministicTimeProvider(startTime: start)

        provider.advance(by: 60)

        #expect(provider.now() == Date(timeIntervalSince1970: 1_060), "sanity")
    }

    @Test("advance accepts negative intervals (time moves backwards)")
    func advancesBackwards() {
        let start = Date(timeIntervalSince1970: 1_000)
        var provider = DeterministicTimeProvider(startTime: start)

        provider.advance(by: -30)

        #expect(provider.now() == Date(timeIntervalSince1970: 970))
    }

    @Test("setTime replaces the current time")
    func setTimeReplaces() {
        var provider = DeterministicTimeProvider(startTime: Date(timeIntervalSince1970: 0))
        let target = Date(timeIntervalSince1970: 5_000)

        provider.setTime(to: target)

        #expect(provider.now() == target)
    }
}
