import Testing
import Foundation
import Riverpods
@testable import StateKitAnalytics

// Spec 009 US6: analytics — ordered funnels with real completion counts,
// bounded journeys with inter-session buffering, flush-failure requeue.

@MainActor
@Suite("Analytics Truth — 009 US6")
struct AnalyticsTruthTests {

    private func event(_ name: String, user: String) -> AnalyticsEvent {
        AnalyticsEvent(name: name, properties: [:], userId: user, sessionId: "s")
    }

    // MARK: T030 — ordered funnel + totalCompletions counts users

    @Test("funnel requires ordered progression; totalCompletions counts users")
    func orderedFunnel() {
        let steps = [
            FunnelAnalyzer.FunnelStep(name: "View", eventName: "view", index: 0),
            FunnelAnalyzer.FunnelStep(name: "Cart", eventName: "cart", index: 1),
            FunnelAnalyzer.FunnelStep(name: "Purchase", eventName: "purchase", index: 2),
        ]
        let analyzer = FunnelAnalyzer(steps: steps)

        // Out-of-order events: purchase BEFORE view — not a completion.
        let inverted = analyzer.analyze(events: [
            event("purchase", user: "u1"),
            event("view", user: "u1"),
        ])
        #expect(inverted.totalCompletions == 0,
                "order-insensitive funnel counted [purchase, view] as a full completion")

        // Ordered progression completes.
        let ordered = analyzer.analyze(events: [
            event("view", user: "u2"),
            event("cart", user: "u2"),
            event("purchase", user: "u2"),
        ])
        #expect(ordered.totalCompletions == 1, "totalCompletions returned a step index, not a user count")

        // Two completions count as two.
        let two = analyzer.analyze(events: [
            event("view", user: "u3"), event("cart", user: "u3"), event("purchase", user: "u3"),
            event("view", user: "u4"), event("cart", user: "u4"), event("purchase", user: "u4"),
        ])
        #expect(two.totalCompletions == 2)
    }

    // MARK: T031 — bounded journeys + inter-session buffering

    @Test("journey tracker bounds retained sessions")
    func boundedSessions() {
        let tracker = UserJourneyTracker(maxSessions: 3)
        tracker.recordEvent(event("e0", user: "u"))

        for _ in 0..<6 {
            tracker.endSession()
            tracker.startNewSession()
        }

        #expect(tracker.sessionCountForTesting <= 3, "sessions grew without bound")
    }

    @Test("events recorded between sessions are replayed, not dropped")
    func interSessionBuffering() {
        let tracker = UserJourneyTracker()
        tracker.endSession()

        tracker.recordEvent(event("orphan-1", user: "u"))
        tracker.recordEvent(event("orphan-2", user: "u"))

        tracker.startNewSession()
        tracker.recordEvent(event("in-session", user: "u"))

        let journey = tracker.journeyForTesting
        let names = journey.map { $0.name }
        #expect(names.contains("orphan-1") && names.contains("orphan-2"),
                "inter-session events were silently dropped")
        #expect(names.contains("in-session"))
    }

    // MARK: T032 — flush failure requeue

    @Test("flush re-queues the batch when the callback reports failure")
    func flushRequeues() {
        let config = AnalyticsConfig(enabled: true, flushInterval: 30, batchSize: 10_000)
        let tracker = EventTracker(config: config)

        var attempts = 0
        var batches: [[Int]] = []
        tracker.onFlush { events -> Bool in
            attempts += 1
            batches.append(events.map { analyticsIntOf($0.properties["n"]) })
            return attempts >= 2   // first attempt fails, second succeeds
        }

        tracker.track("e", properties: ["n": .int(1)])
        tracker.track("e", properties: ["n": .int(2)])
        tracker.flush()
        tracker.flush()

        #expect(attempts == 2)
        #expect(batches[0] == [1, 2])
        #expect(batches[1] == [1, 2], "failed flush lost the events instead of re-queueing")
        #expect(tracker.pendingEvents.isEmpty)
    }

    // MARK: T033 — includeValues serialization

    @Test("provider observer includes values when requested")
    func includeValues() {
        let config = AnalyticsConfig(enabled: true, flushInterval: 30, batchSize: 10_000, historyCap: 10)
        let tracker = EventTracker(config: config)
        let observer = AnalyticsProviderObserver(tracker: tracker, includeValues: true)

        let container = ProviderContainer()
        let provider = StateProvider { _ in 0 }
        _ = container.read(provider)
        _ = container.read(provider.notifier).state = 1

        observer.didUpdateProvider(provider, oldValue: 0, newValue: 1, container: container)

        let tracked = tracker.allEvents
        #expect(!tracked.isEmpty, "observer track() did not record the event")
        guard let last = tracked.last else { return }
        let props = last.properties
        #expect(analyticsIntOf(props["new_value"]) == 1,
                "includeValues recorded the flag but never serialized the values")
        #expect(analyticsIntOf(props["old_value"]) == 0)
    }
}


private func analyticsIntOf(_ codable: AnyCodable?) -> Int {
    guard let data = try? JSONEncoder().encode(codable) else { return -999 }
    return (try? JSONDecoder().decode(Int.self, from: data)) ?? -999
}
