import Foundation

// MARK: - Event Tracker

/// Tracks and batches analytics events.
@MainActor
public final class EventTracker: Sendable {
    private var events: [AnalyticsEvent] = []
    private var batch: [AnalyticsEvent] = []
    private let config: AnalyticsConfig
    private var flushTask: Task<Void, Never>?
    private var onFlush: (([AnalyticsEvent]) -> Void)?

    public init(config: AnalyticsConfig = AnalyticsConfig()) {
        self.config = config
        startAutoFlush()
    }

    deinit {
        flushTask?.cancel()
    }

    /// Tracks event.
    public func track(_ event: AnalyticsEvent) {
        guard config.enabled else { return }

        let trackedEvent = AnalyticsEvent(
            name: event.name,
            properties: event.properties,
            userId: event.userId ?? config.userId,
            sessionId: event.sessionId
        )

        events.append(trackedEvent)
        batch.append(trackedEvent)

        if batch.count >= config.batchSize {
            flush()
        }
    }

    /// Tracks event with properties.
    public func track(_ name: String, properties: [String: AnyCodable] = [:]) {
        let event = AnalyticsEvent(
            name: name,
            properties: properties,
            userId: config.userId,
            sessionId: config.sessionId
        )
        track(event)
    }

    /// Flushes batched events.
    public func flush() {
        guard !batch.isEmpty else { return }

        let eventsToFlush = batch
        batch.removeAll()

        onFlush?(eventsToFlush)
    }

    /// Sets flush callback.
    public func onFlush(_ callback: @escaping ([AnalyticsEvent]) -> Void) {
        self.onFlush = callback
    }

    /// Gets all tracked events.
    public var allEvents: [AnalyticsEvent] {
        events
    }

    /// Gets pending batched events.
    public var pendingEvents: [AnalyticsEvent] {
        batch
    }

    /// Number of events tracked.
    public var eventCount: Int {
        events.count
    }

    /// Clears all events.
    public func clearEvents() {
        events.removeAll()
        batch.removeAll()
    }

    // MARK: - Auto Flush

    private func startAutoFlush() {
        flushTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(config.flushInterval * 1_000_000_000))

                if !Task.isCancelled && !batch.isEmpty {
                    flush()
                }
            }
        }
    }
}

// MARK: - Event Logger

/// Logs events for debugging.
public struct EventLogger: Sendable {
    private let tracker: EventTracker

    public init(tracker: EventTracker) {
        self.tracker = tracker
    }

    /// Logs all events as JSON.
    public func logEvents() -> String {
        let events = tracker.allEvents
        var json = "[\n"

        for (index, event) in events.enumerated() {
            let dict = event.toDictionary()
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let jsonString = String(data: data, encoding: .utf8) {
                json += "  \(jsonString)"
                if index < events.count - 1 {
                    json += ","
                }
                json += "\n"
            }
        }

        json += "]"
        return json
    }

    /// Gets summary of events by name.
    public func summary() -> [String: Int] {
        var counts: [String: Int] = [:]

        for event in tracker.allEvents {
            counts[event.name, default: 0] += 1
        }

        return counts
    }
}

// MARK: - Event Filter

/// Filters events for analysis.
public struct EventFilter: Sendable {
    private let events: [AnalyticsEvent]

    public init(events: [AnalyticsEvent]) {
        self.events = events
    }

    /// Filters by event name.
    public func byName(_ name: String) -> [AnalyticsEvent] {
        events.filter { $0.name == name }
    }

    /// Filters by user ID.
    public func byUser(_ userId: String) -> [AnalyticsEvent] {
        events.filter { $0.userId == userId }
    }

    /// Filters by date range.
    public func byDate(from: Date, to: Date) -> [AnalyticsEvent] {
        events.filter { $0.timestamp >= from && $0.timestamp <= to }
    }

    /// Filters by property value.
    public func byProperty(_ key: String, value: AnyCodable) -> [AnalyticsEvent] {
        events.filter { event in
            if let prop = event.properties[key], prop == value {
                return true
            }
            return false
        }
    }
}

// MARK: - Codable Comparison

extension AnyCodable: Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let a), .bool(let b)): return a == b
        case (.int(let a), .int(let b)): return a == b
        case (.double(let a), .double(let b)): return abs(a - b) < 0.0001
        case (.string(let a), .string(let b)): return a == b
        case (.array(let a), .array(let b)): return a == b
        case (.dictionary(let a), .dictionary(let b)): return a == b
        default: return false
        }
    }
}
