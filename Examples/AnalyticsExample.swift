import Foundation
import StateKitAnalytics

// MARK: - Analytics Example: Event Tracking and Funnel Analysis

/// Demonstrates analytics tracking, user journey analysis, and funnel conversion metrics.
/// Shows how to understand user behavior through structured event tracking and analysis.

// MARK: - User Models

struct AppUser: Sendable {
    let id: String
    let email: String
    let signupDate: Date
    let plan: String  // "free", "pro", "enterprise"
}

// MARK: - Mock Event Generator

struct EventSimulator: Sendable {
    let users: [AppUser]

    /// Generates realistic user journey events
    func generateUserJourney() -> [AnalyticsEvent] {
        var events: [AnalyticsEvent] = []

        for (index, user) in users.enumerated() {
            let sessionId = UUID().uuidString
            let baseTime = Date().addingTimeInterval(-TimeInterval(index * 3600))

            // App launch
            events.append(AnalyticsEvent(
                name: StandardEvent.appLaunched,
                properties: [
                    "plan": .string(user.plan),
                    "version": .string("2.6.0")
                ],
                userId: user.id,
                sessionId: sessionId
            ))

            // Browse products
            for productIndex in 0..<Int.random(in: 2...5) {
                events.append(AnalyticsEvent(
                    name: "product_viewed",
                    properties: [
                        "product_id": .string("prod-\(productIndex)"),
                        "category": .string(["electronics", "clothing", "books"].randomElement() ?? "other"),
                        "price": .double(Double.random(in: 10...500))
                    ],
                    userId: user.id,
                    sessionId: sessionId
                ))
            }

            // Add to cart (75% chance)
            if Bool.random(weighted: 0.75) {
                events.append(AnalyticsEvent(
                    name: "item_added",
                    properties: [
                        "product_id": .string("prod-0"),
                        "quantity": .int(Int.random(in: 1...3)),
                        "price": .double(Double.random(in: 10...500))
                    ],
                    userId: user.id,
                    sessionId: sessionId
                ))

                // Checkout (80% of those who add to cart)
                if Bool.random(weighted: 0.80) {
                    events.append(AnalyticsEvent(
                        name: "checkout_started",
                        properties: [
                            "cart_value": .double(Double.random(in: 50...1000)),
                            "items_count": .int(Int.random(in: 1...5))
                        ],
                        userId: user.id,
                        sessionId: sessionId
                    ))

                    // Purchase (85% of those who start checkout)
                    if Bool.random(weighted: 0.85) {
                        events.append(AnalyticsEvent(
                            name: "purchase_completed",
                            properties: [
                                "order_value": .double(Double.random(in: 50...1000)),
                                "items": .int(Int.random(in: 1...5)),
                                "payment_method": .string(["credit_card", "paypal", "apple_pay"].randomElement() ?? "other")
                            ],
                            userId: user.id,
                            sessionId: sessionId
                        ))
                    }
                }
            }
        }

        return events
    }
}

// Helper for weighted probability
extension Bool {
    static func random(weighted probability: Double) -> Bool {
        Double.random(in: 0...1) < probability
    }
}

// MARK: - Analytics Dashboard

struct AnalyticsDashboard: Sendable {
    let events: [AnalyticsEvent]

    func printSummary() {
        print("\n📊 Analytics Summary")
        print("─" * 50)

        // Total events
        print("Total events: \(events.count)")
        print("Unique users: \(Set(events.compactMap { $0.userId }).count)")
        print("Time range: \(events.count) events\n")

        // Event breakdown
        print("Events by type:")
        let eventCounts = Dictionary(grouping: events, by: { $0.name })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        for (eventName, count) in eventCounts {
            print("  • \(eventName): \(count)")
        }
        print()
    }

    func printConversionFunnel() {
        print("\n🔻 Conversion Funnel")
        print("─" * 50)

        let funnelSteps = [
            FunnelAnalyzer.FunnelStep(name: "View Product", eventName: "product_viewed", index: 0),
            FunnelAnalyzer.FunnelStep(name: "Add to Cart", eventName: "item_added", index: 1),
            FunnelAnalyzer.FunnelStep(name: "Checkout", eventName: "checkout_started", index: 2),
            FunnelAnalyzer.FunnelStep(name: "Purchase", eventName: "purchase_completed", index: 3),
        ]

        let analyzer = FunnelAnalyzer(steps: funnelSteps)
        let result = analyzer.analyze(events: events)

        for (index, step) in funnelSteps.enumerated() {
            let rate = result.conversionRates[index]
            let usersAtStep = result.completions.values.filter { $0 >= index }.count
            let percentage = String(format: "%.1f", rate * 100)
            let barLength = Int(rate * 30)
            let bar = String(repeating: "█", count: barLength)
            print("  \(step.name)")
            print("    Users: \(usersAtStep) (\(percentage)%) \(bar)")
        }

        // Calculate drop-off rates
        print("\nDrop-off Analysis:")
        let dropoffAnalyzer = DropoffAnalyzer(funnel: ["product_viewed", "item_added", "checkout_started", "purchase_completed"])
        let dropoffRates = dropoffAnalyzer.analyzeDropoff(events: events)

        for step in funnelSteps.dropLast() {
            if let nextStep = funnelSteps.first(where: { $0.index == step.index + 1 }) {
                let dropoff = dropoffAnalyzer.dropoffRate(events: events, from: step.eventName, to: nextStep.eventName)
                let percentage = String(format: "%.1f", dropoff * 100)
                print("  \(step.name) → \(nextStep.name): \(percentage)% drop-off")
            }
        }
        print()
    }

    func printCohortAnalysis() {
        print("\n👥 Cohort Retention Analysis")
        print("─" * 50)

        let cohortAnalyzer = CohortAnalyzer()
        let cohorts = cohortAnalyzer.analyzeCohorts(events: events, onEvent: "app_launched")

        for cohort in cohorts {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let weekLabel = formatter.string(from: cohort.weekStarting)

            print("Week of \(weekLabel)")
            print("  Size: \(cohort.size) users")
            print("  Retention by week:")
            for (week, rate) in cohort.retentionByWeek.enumerated() {
                let percentage = String(format: "%.0f", rate * 100)
                let bar = String(repeating: "█", count: Int(rate * 20))
                print("    Week \(week): \(percentage)% \(bar)")
            }
            print()
        }
    }

    func printUserSegments() {
        print("\n🎯 User Segment Analysis")
        print("─" * 50)

        var userSegments: [String: [String]] = [:]

        for event in events {
            if let userId = event.userId,
               let planProp = event.properties["plan"],
               case .string(let plan) = planProp {
                if userSegments[plan] == nil {
                    userSegments[plan] = []
                }
                if !userSegments[plan]!.contains(userId) {
                    userSegments[plan]!.append(userId)
                }
            }
        }

        for (plan, users) in userSegments.sorted(by: { $0.value.count > $1.value.count }) {
            let conversions = events.filter { event in
                users.contains(event.userId ?? "") && event.name == "purchase_completed"
            }.count

            let conversionRate = Double(conversions) / Double(users.count)
            let percentage = String(format: "%.1f", conversionRate * 100)

            print("  \(plan.uppercased())")
            print("    Users: \(users.count)")
            print("    Conversions: \(conversions) (\(percentage)%)")
        }
        print()
    }
}

// MARK: - Analytics Example Demonstration

@main
struct AnalyticsExampleApp {
    static func main() {
        print("=== StateKit Analytics Example ===\n")

        // Create sample users
        let users = [
            AppUser(id: "user-1", email: "alice@example.com", signupDate: Date().addingTimeInterval(-86400 * 7), plan: "pro"),
            AppUser(id: "user-2", email: "bob@example.com", signupDate: Date().addingTimeInterval(-86400 * 5), plan: "free"),
            AppUser(id: "user-3", email: "charlie@example.com", signupDate: Date().addingTimeInterval(-86400 * 3), plan: "enterprise"),
            AppUser(id: "user-4", email: "diana@example.com", signupDate: Date().addingTimeInterval(-86400 * 1), plan: "pro"),
            AppUser(id: "user-5", email: "eve@example.com", signupDate: Date(), plan: "free"),
        ]

        // Demo 1: Event Tracking
        print("📊 Demo 1: Event Tracking")
        let config = AnalyticsConfig(
            enabled: true,
            flushInterval: 5,
            batchSize: 10
        )
        let tracker = EventTracker(config: config)

        // Track standard events
        tracker.track(StandardEvent.appLaunched, properties: ["version": .string("2.6.0")])
        tracker.track(StandardEvent.screenViewed, properties: ["screen": .string("home")])
        tracker.track("item_purchased", properties: ["value": .double(99.99)])

        print("✓ Tracked 3 events")
        print("  All events: \(tracker.eventCount)")
        print("  Pending events: \(tracker.pendingEvents.count)\n")

        // Demo 2: Event Summary
        print("📊 Demo 2: Event Logging & Summary")
        let logger = EventLogger(tracker: tracker)
        let summary = logger.summary()
        print("Event summary:")
        for (eventName, count) in summary.sorted(by: { $0.value > $1.value }) {
            print("  • \(eventName): \(count)")
        }
        print()

        // Demo 3: User Journey & Session Tracking
        print("📊 Demo 3: User Journey Tracking")
        let journeyTracker = UserJourneyTracker()
        journeyTracker.startNewSession(properties: ["source": .string("app_store")])

        journeyTracker.recordEvent(AnalyticsEvent(
            name: "screen_viewed",
            properties: ["screen": .string("products")],
            userId: "user-1"
        ))
        journeyTracker.recordEvent(AnalyticsEvent(
            name: "product_viewed",
            properties: ["product_id": .string("prod-123")],
            userId: "user-1"
        ))
        journeyTracker.recordEvent(AnalyticsEvent(
            name: "item_added",
            properties: ["product_id": .string("prod-123"), "quantity": .int(2)],
            userId: "user-1"
        ))

        if let sessionId = journeyTracker.currentSessionId {
            let journey = journeyTracker.journey(sessionId: sessionId)
            print("✓ Session \(sessionId.prefix(8))...")
            print("  Events recorded: \(journey.count)")
            for event in journey {
                print("    • \(event.name)")
            }
        }
        print()

        // Demo 4: Simulated User Analytics
        print("📊 Demo 4: Simulated User Analytics")
        let simulator = EventSimulator(users: users)
        let simulatedEvents = simulator.generateUserJourney()
        print("✓ Generated \(simulatedEvents.count) events for \(users.count) users\n")

        // Create dashboard
        let dashboard = AnalyticsDashboard(events: simulatedEvents)

        // Demo 5: Analytics Dashboard
        print("📊 Demo 5: Analytics Dashboard")
        dashboard.printSummary()

        // Demo 6: Conversion Funnel
        print("📊 Demo 6: Conversion Funnel Analysis")
        dashboard.printConversionFunnel()

        // Demo 7: Cohort Analysis
        print("📊 Demo 7: Cohort Retention Analysis")
        dashboard.printCohortAnalysis()

        // Demo 8: User Segment Analysis
        print("📊 Demo 8: User Segment Analysis")
        dashboard.printUserSegments()

        // Demo 9: Event Filtering
        print("📊 Demo 9: Event Filtering")
        let filter = EventFilter(events: simulatedEvents)
        let purchases = filter.byName("purchase_completed")
        let freeUsers = filter.byProperty("plan", value: .string("free"))

        print("Purchases: \(purchases.count)")
        print("Free plan users: \(freeUsers.count)")
        print("Free users who purchased: \(Set(purchases.map { $0.userId }).intersection(Set(freeUsers.map { $0.userId })).count)\n")

        print("✅ Analytics example completed!")
        print("Key takeaways:")
        print("• Event tracking provides behavioral insights")
        print("• Funnel analysis identifies conversion bottlenecks")
        print("• Cohort analysis reveals retention patterns")
        print("• Segmentation helps understand user groups")
        print("• Batch collection optimizes backend efficiency")
    }
}
