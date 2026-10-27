import Foundation
import Observation

// MARK: - Event Tracker

/// Tracks and batches analytics events.
@MainActor
public final class EventTracker: Sendable {
    private var events: [AnalyticsEvent] = []
    private var batch: [AnalyticsEvent] = []
    private let config: AnalyticsConfig
    private var flushTask: Task<Void, Never>?
    private var onFlush: (([AnalyticsEvent]) -> Void)?
    private var onFlushResult: (([AnalyticsEvent]) -> Bool)?

    /// Creates a tracker; auto-flush starts immediately.
    public init(config: AnalyticsConfig = AnalyticsConfig()) {
        self.config = config
        if config.persistLocal {
            localPersistence = { events in
                Self.persistLocally(events)
            }
        }
        startAutoFlush(interval: config.flushInterval)
    }

    /// Appends flushed events as JSON lines to a file in the platform caches
    /// directory (`statekit-analytics-events.jsonl`), truncated back to empty
    /// past 1 MB so the sink never grows without bound.
    private static func persistLocally(_ events: [AnalyticsEvent]) {
        let url = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("statekit-analytics-events.jsonl")
        guard let url else { return }
        var text = ""
        for event in events {
            if let data = try? JSONSerialization.data(withJSONObject: event.toDictionary()),
               let line = String(data: data, encoding: .utf8) {
                text += line + "\n"
            }
        }
        if let existing = try? String(contentsOf: url, encoding: .utf8), existing.count > 1_000_000 {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(text.utf8))
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
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

        // Retained history is bounded, opt-in debug tooling: an uncapped mirror
        // of every tracked event grows for the tracker's (process) lifetime.
        if let cap = config.historyCap {
            events.append(trackedEvent)
            if events.count > cap {
                events.removeFirst(events.count - cap)
            }
        }
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
    ///
    /// With a result-reporting callback (`onFlush(_:) -> Bool`), a `false`
    /// return re-prepends the events so the next flush retries. The
    /// fire-and-forget callback never re-queues.
    public func flush() {
        guard !batch.isEmpty else { return }

        let eventsToFlush = batch
        batch.removeAll()

        if let resultCallback = onFlushResult {
            if !resultCallback(eventsToFlush) {
                batch.insert(contentsOf: eventsToFlush, at: 0)
            }
            return
        }

        onFlush?(eventsToFlush)
        if let persist = localPersistence {
            persist(eventsToFlush)
        }
    }

    /// Local persistence sink for `AnalyticsConfig.persistLocal`: appends
    /// flushed batches as JSON lines (called after a successful hand-off).
    @ObservationIgnored
    var localPersistence: (([AnalyticsEvent]) -> Void)?

    /// Sets flush callback (fire-and-forget: the batch is considered
    /// delivered once handed off).
    public func onFlush(_ callback: @escaping ([AnalyticsEvent]) -> Void) {
        self.onFlush = callback
    }

    /// Sets a flush callback that reports delivery. Returning `false` re-queues
    /// the batch so the next flush retries instead of losing the events.
    public func onFlush(_ callback: @escaping ([AnalyticsEvent]) -> Bool) {
        self.onFlushResult = callback
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

    /// Runs `flush()` every `config.flushInterval` until the tracker is
    /// deallocated.
    ///
    /// The interval is captured by value and `self` weakly: releasing the
    /// tracker must let it deallocate and stop the loop (no orphan wakeups).
    private func startAutoFlush(interval: TimeInterval) {
        flushTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                guard let self, !Task.isCancelled else { break }
                if !self.batch.isEmpty {
                    self.flush()
                }
            }
        }
    }
}

// MARK: - Event Logger

/// Logs events for debugging.
@MainActor
public struct EventLogger: Sendable {
    private let tracker: EventTracker

    /// Wraps a tracker for logging its events.
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

    /// Wraps an event list for reporting.
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
