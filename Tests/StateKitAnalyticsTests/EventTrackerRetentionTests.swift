import Testing
import Foundation
@testable import StateKitAnalytics

// Spec 008 US8: EventTracker must not retain an unbounded event history.
// Default: no retained history beyond the active batch. Opt-in debug
// retention: explicit cap with drop-oldest semantics. track()/flush()
// contracts are unchanged.

@MainActor
@Suite("EventTracker Retention — P1 fixes")
struct EventTrackerRetentionTests {

    @Test("default tracker retains no unbounded history")
    func defaultHasNoRetention() {
        let config = AnalyticsConfig(enabled: true, flushInterval: 30, batchSize: 10_000)
        let tracker = EventTracker(config: config)

        for index in 0..<1000 {
            tracker.track("event_\(index)")
        }

        #expect(tracker.allEvents.isEmpty,
                "tracker grew without bound: every tracked event is retained forever")
        #expect(tracker.eventCount == 0)
    }

    @Test("opt-in retention is capped with drop-oldest semantics")
    func cappedRetention() {
        let config = AnalyticsConfig(enabled: true, flushInterval: 30, batchSize: 10_000, historyCap: 10)
        let tracker = EventTracker(config: config)

        for index in 0..<25 {
            tracker.track("event_\(index)")
        }

        #expect(tracker.allEvents.count == 10)
        #expect(tracker.allEvents.first?.name == "event_15", "oldest events must be dropped first")
        #expect(tracker.allEvents.last?.name == "event_24")
        #expect(tracker.eventCount == 10)
    }

    @Test("track and flush contracts are unchanged with retention enabled")
    func flushContractUnchanged() {
        var flushed: [[AnalyticsEvent]] = []
        let config = AnalyticsConfig(enabled: true, flushInterval: 30, batchSize: 3, historyCap: 100)
        let tracker = EventTracker(config: config)
        tracker.onFlush { flushed.append($0) }

        for index in 0..<7 {
            tracker.track("event_\(index)")
        }

        #expect(flushed.count == 2, "batchSize=3 should auto-flush twice (3+3)")
        #expect(tracker.pendingEvents.count == 1, "one event remains in the batch")
    }

    @Test("clearEvents clears retained history")
    func clearEventsWorks() {
        let config = AnalyticsConfig(enabled: true, flushInterval: 30, batchSize: 10_000, historyCap: 50)
        let tracker = EventTracker(config: config)

        tracker.track("a")
        tracker.track("b")
        #expect(tracker.eventCount == 2)

        tracker.clearEvents()
        #expect(tracker.eventCount == 0)
        #expect(tracker.allEvents.isEmpty)
    }
}
