import XCTest
import StateKitAnalytics

@MainActor
final class AnalyticsTests: XCTestCase {
    // MARK: - Event Tracker Tests

    func testEventTracking() {
        let tracker = EventTracker()

        tracker.track("test_event", properties: ["value": .int(42)])

        XCTAssertEqual(tracker.eventCount, 1)
        XCTAssertEqual(tracker.allEvents.first?.name, "test_event")
    }

    func testEventBatching() {
        let config = AnalyticsConfig(batchSize: 3)
        let tracker = EventTracker(config: config)
        var flushedCount = 0

        tracker.onFlush { events in
            flushedCount = events.count
        }

        tracker.track("event1")
        tracker.track("event2")
        XCTAssertEqual(flushedCount, 0)  // Not flushed yet

        tracker.track("event3")
        XCTAssertEqual(flushedCount, 3)  // Flushed on batch size
    }

    func testEventFilter() {
        let events = [
            AnalyticsEvent(name: "view", userId: "user1"),
            AnalyticsEvent(name: "click", userId: "user1"),
            AnalyticsEvent(name: "view", userId: "user2"),
        ]

        let filter = EventFilter(events: events)
        let views = filter.byName("view")
        let user1Events = filter.byUser("user1")

        XCTAssertEqual(views.count, 2)
        XCTAssertEqual(user1Events.count, 2)
    }

    // MARK: - User Journey Tests

    func testSessionTracking() {
        let journey = UserJourneyTracker()

        journey.recordEvent(AnalyticsEvent(name: "event1", userId: "user1"))
        journey.recordEvent(AnalyticsEvent(name: "event2", userId: "user1"))

        if let sessionId = journey.currentSessionId {
            let events = journey.journey(sessionId: sessionId)
            XCTAssertEqual(events.count, 2)
        }
    }

    func testSessionEnd() {
        let journey = UserJourneyTracker()
        let sessionId = journey.currentSessionId!

        journey.recordEvent(AnalyticsEvent(name: "event1", userId: "user1"))
        journey.endSession()

        let session = journey.session(id: sessionId)
        XCTAssertNotNil(session?.endTime)
        XCTAssertEqual(session?.eventCount, 1)
    }

    // MARK: - Funnel Analysis Tests

    func testFunnelAnalysis() {
        let steps = [
            FunnelAnalyzer.FunnelStep(name: "View", eventName: "view", index: 0),
            FunnelAnalyzer.FunnelStep(name: "Click", eventName: "click", index: 1),
            FunnelAnalyzer.FunnelStep(name: "Purchase", eventName: "purchase", index: 2),
        ]

        let events = [
            AnalyticsEvent(name: "view", userId: "user1"),
            AnalyticsEvent(name: "click", userId: "user1"),
            AnalyticsEvent(name: "purchase", userId: "user1"),
            AnalyticsEvent(name: "view", userId: "user2"),
            AnalyticsEvent(name: "click", userId: "user2"),
        ]

        let analyzer = FunnelAnalyzer(steps: steps)
        let result = analyzer.analyze(events: events)

        XCTAssertEqual(result.conversionRates[0], 1.0)  // 100% viewed
        XCTAssertEqual(result.conversionRates[1], 1.0)  // 100% clicked
        XCTAssertEqual(result.conversionRates[2], 0.5)  // 50% purchased
    }

    // MARK: - Drop-off Analysis Tests

    func testDropoffAnalysis() {
        let dropoff = DropoffAnalyzer(funnel: ["view", "click", "purchase"])

        let events = [
            AnalyticsEvent(name: "view", userId: "user1"),
            AnalyticsEvent(name: "click", userId: "user1"),
            AnalyticsEvent(name: "purchase", userId: "user1"),
            AnalyticsEvent(name: "view", userId: "user2"),
        ]

        let dropoffs = dropoff.analyzeDropoff(events: events)
        XCTAssertEqual(dropoffs["view"], 2)  // 2 users viewed
        XCTAssertEqual(dropoffs["click"], 1)  // 1 user clicked
    }

    func testDropoffRate() {
        let dropoff = DropoffAnalyzer(funnel: ["view", "click", "purchase"])

        let events = [
            AnalyticsEvent(name: "view", userId: "user1"),
            AnalyticsEvent(name: "click", userId: "user1"),
            AnalyticsEvent(name: "purchase", userId: "user1"),
            AnalyticsEvent(name: "view", userId: "user2"),
            AnalyticsEvent(name: "view", userId: "user3"),
        ]

        let rate = dropoff.dropoffRate(events: events, from: "view", to: "click")
        XCTAssertEqual(rate, 2.0 / 3.0)  // 2 out of 3 viewers dropped off
    }

    // MARK: - AnyCodable Tests

    func testAnyCodableEquality() {
        let value1 = AnyCodable.int(42)
        let value2 = AnyCodable.int(42)
        let value3 = AnyCodable.int(43)

        XCTAssertEqual(value1, value2)
        XCTAssertNotEqual(value1, value3)
    }

    func testAnyCodableString() {
        let value1 = AnyCodable.string("hello")
        let value2 = AnyCodable.string("hello")

        XCTAssertEqual(value1, value2)
    }

    // MARK: - Standard Events Tests

    func testStandardEventNames() {
        XCTAssertEqual(StandardEvent.appLaunched, "app_launched")
        XCTAssertEqual(StandardEvent.userSignedIn, "user_signed_in")
        XCTAssertEqual(StandardEvent.screenViewed, "screen_viewed")
    }

    // MARK: - Analytics Configuration Tests

    func testAnalyticsConfig() {
        let config = AnalyticsConfig(
            enabled: true,
            flushInterval: 60,
            batchSize: 100
        )

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.flushInterval, 60)
        XCTAssertEqual(config.batchSize, 100)
    }
}
