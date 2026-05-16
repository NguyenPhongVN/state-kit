import Foundation

// MARK: - User Journey Tracking

/// Tracks user journey through app (sessions, funnels, conversions).
@MainActor
public final class UserJourneyTracker: Sendable {
    public struct Session: Sendable {
        public let id: String
        public let userId: String
        public let startTime: Date
        public let endTime: Date?
        public let eventCount: Int
        public let properties: [String: AnyCodable]

        public var duration: TimeInterval? {
            endTime.map { $0.timeIntervalSince(startTime) }
        }
    }

    private var sessions: [String: Session] = [:]
    private var currentSession: Session?
    private var journeys: [String: [AnalyticsEvent]] = [:]

    public init() {
        startNewSession()
    }

    /// Starts new session.
    public func startNewSession(userId: String? = nil, properties: [String: AnyCodable] = [:]) {
        let session = Session(
            id: UUID().uuidString,
            userId: userId ?? UUID().uuidString,
            startTime: Date(),
            endTime: nil,
            eventCount: 0,
            properties: properties
        )
        currentSession = session
        journeys[session.id] = []
    }

    /// Ends current session.
    public func endSession() {
        guard let session = currentSession else { return }

        let endedSession = Session(
            id: session.id,
            userId: session.userId,
            startTime: session.startTime,
            endTime: Date(),
            eventCount: journeys[session.id]?.count ?? 0,
            properties: session.properties
        )
        sessions[session.id] = endedSession
        currentSession = nil
    }

    /// Records event in session.
    public func recordEvent(_ event: AnalyticsEvent) {
        guard let sessionId = currentSession?.id else { return }

        journeys[sessionId]?.append(event)
    }

    /// Gets current session ID.
    public var currentSessionId: String? {
        currentSession?.id
    }

    /// Gets all sessions.
    public var allSessions: [Session] {
        Array(sessions.values)
    }

    /// Gets session by ID.
    public func session(id: String) -> Session? {
        sessions[id] ?? currentSession
    }

    /// Gets journey (events) for session.
    public func journey(sessionId: String) -> [AnalyticsEvent] {
        journeys[sessionId] ?? []
    }
}

// MARK: - Funnel Analysis

/// Analyzes conversion funnels.
public struct FunnelAnalyzer: Sendable {
    public struct FunnelStep: Sendable {
        public let name: String
        public let eventName: String
        public let index: Int
    }

    public struct FunnelResult: Sendable {
        public let steps: [FunnelStep]
        public let completions: [String: Int]  // userId -> step completed to
        public let conversionRates: [Double]   // Percentage for each step

        public var totalCompletions: Int {
            completions.values.max() ?? 0
        }
    }

    private let steps: [FunnelStep]

    public init(steps: [FunnelStep]) {
        self.steps = steps
    }

    /// Analyzes funnel from events.
    public func analyze(events: [AnalyticsEvent]) -> FunnelResult {
        var completions: [String: Int] = [:]

        for event in events {
            guard let userId = event.userId else { continue }

            for (index, step) in steps.enumerated() {
                if event.name == step.eventName {
                    completions[userId] = max(index, completions[userId] ?? 0)
                }
            }
        }

        // Calculate conversion rates
        var conversionRates: [Double] = []
        let totalUsers = Set(events.compactMap { $0.userId }).count

        for stepIndex in 0..<steps.count {
            let usersReachingStep = completions.values.filter { $0 >= stepIndex }.count
            let rate = totalUsers > 0 ? Double(usersReachingStep) / Double(totalUsers) : 0
            conversionRates.append(rate)
        }

        return FunnelResult(
            steps: steps,
            completions: completions,
            conversionRates: conversionRates
        )
    }
}

// MARK: - Drop-off Analysis

/// Analyzes where users drop off.
public struct DropoffAnalyzer: Sendable {
    private let funnel: [String]  // Event names in order

    public init(funnel: [String]) {
        self.funnel = funnel
    }

    /// Finds drop-off points.
    public func analyzeDropoff(events: [AnalyticsEvent]) -> [String: Int] {
        var dropoffs: [String: Int] = [:]

        for step in funnel {
            let stepEvents = events.filter { $0.name == step }
            let count = Set(stepEvents.compactMap { $0.userId }).count
            dropoffs[step] = count
        }

        return dropoffs
    }

    /// Gets drop-off rate between steps.
    public func dropoffRate(events: [AnalyticsEvent], from: String, to: String) -> Double {
        guard let fromIndex = funnel.firstIndex(of: from),
              let toIndex = funnel.firstIndex(of: to),
              fromIndex < toIndex else { return 0 }

        let fromCount = Set(events.filter { $0.name == from }.compactMap { $0.userId }).count
        let toCount = Set(events.filter { $0.name == to }.compactMap { $0.userId }).count

        return fromCount > 0 ? Double(fromCount - toCount) / Double(fromCount) : 0
    }
}

// MARK: - Cohort Analysis

/// Analyzes user cohorts by signup date.
public struct CohortAnalyzer: Sendable {
    public struct Cohort: Sendable {
        public let weekStarting: Date
        public let size: Int
        public let retentionByWeek: [Double]
    }

    /// Analyzes retention cohorts.
    public func analyzeCohorts(events: [AnalyticsEvent], onEvent: String = "app_launched") -> [Cohort] {
        var cohorts: [Date: Set<String>] = [:]

        for event in events.filter({ $0.name == onEvent }) {
            guard let userId = event.userId else { continue }

            let weekStart = weekStart(for: event.timestamp)
            if cohorts[weekStart] == nil {
                cohorts[weekStart] = []
            }
            cohorts[weekStart]?.insert(userId)
        }

        return cohorts
            .sorted { $0.key < $1.key }
            .map { weekStart, users in
                Cohort(
                    weekStarting: weekStart,
                    size: users.count,
                    retentionByWeek: calculateRetention(users, from: weekStart, in: events)
                )
            }
    }

    private func weekStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    private func calculateRetention(_ users: Set<String>, from: Date, in events: [AnalyticsEvent]) -> [Double] {
        var retention: [Double] = []

        for week in 0..<4 {
            let weekDate = Calendar.current.date(byAdding: .weekOfYear, value: week, to: from) ?? from
            let activeUsers = Set(
                events
                    .filter { $0.timestamp >= weekDate && $0.timestamp < Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekDate) ?? weekDate }
                    .compactMap { $0.userId }
            )
            .intersection(users)

            let rate = users.isEmpty ? 0 : Double(activeUsers.count) / Double(users.count)
            retention.append(rate)
        }

        return retention
    }
}
