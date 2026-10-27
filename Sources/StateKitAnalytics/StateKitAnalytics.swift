import Foundation
import Riverpods

// MARK: - StateKit Analytics Module

/// StateKitAnalytics provides event tracking, state change analytics, and user journey tracking.
///
/// Features:
/// - Structured event recording with properties
/// - Automatic state change tracking via ProviderObserver
/// - User session and journey tracking
/// - Funnel analysis and conversion tracking
/// - Event batching and flushing strategies

public enum StateKitAnalytics {
    public static let version = "2.6.0-beta"
}

// MARK: - Analytics Event

/// Structured analytics event.
public struct AnalyticsEvent: Sendable {
    /// Event name (snake_case by convention).
    public let name: String
    /// When the event was tracked.
    public let timestamp: Date
    /// Structured payload attached to the event.
    public let properties: [String: AnyCodable]
    /// Acting user, if known.
    public let userId: String?
    /// Session the event belongs to.
    public let sessionId: String

    /// Creates an event timestamped now.
    public init(
        name: String,
        properties: [String: AnyCodable] = [:],
        userId: String? = nil,
        sessionId: String = UUID().uuidString
    ) {
        self.name = name
        self.timestamp = Date()
        self.properties = properties
        self.userId = userId
        self.sessionId = sessionId
    }

    /// Encodes event to dictionary.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "event": name,
            "timestamp": timestamp.timeIntervalSince1970,
            "session_id": sessionId,
        ]

        if let userId = userId {
            dict["user_id"] = userId
        }

        for (key, value) in properties {
            dict[key] = value
        }

        return dict
    }
}

// MARK: - Type-Erased Codable

/// Type-erased Codable value for analytics properties.
public enum AnyCodable: Sendable, Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])

    /// Decodes with lenient defaults for optional fields.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    /// Encodes all fields for wire/storage formats.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        }
    }
}

// MARK: - Analytics Configuration

/// Configuration for analytics collection.
public struct AnalyticsConfig: Sendable {
    /// Master switch; tracking is a no-op when off.
    public let enabled: Bool
    /// Seconds between automatic flushes.
    public let flushInterval: TimeInterval
    /// Events per flush trigger.
    public let batchSize: Int
    /// Whether events persist locally between launches.
    public let persistLocal: Bool
    /// Maximum events retained in memory for inspection; `nil` (default)
    /// retains nothing beyond the active batch. Retention exists for debugging
    /// only — flushed events are never re-sent.
    public let historyCap: Int?
    /// Default user attributed to tracked events.
    public let userId: String?
    /// Session attributed to tracked events.
    public let sessionId: String

    /// Creates configuration with defaults for anything omitted.
    public init(
        enabled: Bool = true,
        flushInterval: TimeInterval = 30,
        batchSize: Int = 50,
        persistLocal: Bool = false,
        historyCap: Int? = nil,
        userId: String? = nil,
        sessionId: String = UUID().uuidString
    ) {
        self.enabled = enabled
        self.flushInterval = max(1, flushInterval)
        self.batchSize = max(1, batchSize)
        self.persistLocal = persistLocal
        self.historyCap = historyCap.map { max(1, $0) }
        self.userId = userId
        self.sessionId = sessionId
    }
}

// MARK: - Best-Effort Encoding

extension AnyCodable {
    /// Encodes any value into an `AnyCodable`; values JSON cannot represent
    /// degrade to their debug description so "include values" never silently
    /// drops the data it was asked for.
    static func encodeBestEffort(_ value: some Any) -> AnyCodable {
        if let encodable = value as? any Encodable {
            if let codable = encodable as? any AnyCodableConvertible {
                return codable.anyCodable
            }
            if let data = try? JSONEncoder().encode(EncodableBox(encodable)),
               let any = try? JSONDecoder().decode(AnyCodable.self, from: data) {
                return any
            }
        }
        return .string(String(describing: value))
    }
}

/// Type-erasing box so heterogeneous provider state can round-trip through
/// JSONEncoder into `AnyCodable`.
private struct EncodableBox: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ value: any Encodable) {
        self.encodeFunc = value.encode
    }
    func encode(to encoder: any Encoder) throws {
        try encodeFunc(encoder)
    }
}

/// Escape hatch for values that already wrap `AnyCodable`.
public protocol AnyCodableConvertible {
    var anyCodable: AnyCodable { get }
}

extension AnyCodable: AnyCodableConvertible {
    public var anyCodable: AnyCodable { self }
}

// MARK: - Analytics Provider Observer

/// Observes provider changes and records as analytics events.
@MainActor
public final class AnalyticsProviderObserver: ProviderObserver {
    private let tracker: EventTracker
    private let includeValues: Bool

    /// Creates the logger over a tracker (values excluded unless requested).
    public init(tracker: EventTracker, includeValues: Bool = false) {
        self.tracker = tracker
        self.includeValues = includeValues
    }

    /// Tracks one event per provider update.
    public func didUpdateProvider<P: ProviderProtocol>(
        _ provider: P,
        oldValue: P.State,
        newValue: P.State,
        container: ProviderContainer
    ) {
        var properties: [String: AnyCodable] = [
            "provider": .string(String(describing: type(of: provider))),
        ]
        if includeValues {
            // Serialize the requested values; non-JSON-encodable state degrades
            // to its debug description instead of silently dropping the flag.
            properties["old_value"] = AnyCodable.encodeBestEffort(oldValue)
            properties["new_value"] = AnyCodable.encodeBestEffort(newValue)
        }
        let event = AnalyticsEvent(
            name: "state_changed",
            properties: properties
        )

        tracker.track(event)
    }
}

// MARK: - Common Events

/// Standard event names.
public enum StandardEvent {
    public static let appLaunched = "app_launched"
    public static let appForegrounded = "app_foregrounded"
    public static let appBackgrounded = "app_backgrounded"
    public static let appTerminated = "app_terminated"
    public static let userSignedIn = "user_signed_in"
    public static let userSignedOut = "user_signed_out"
    public static let screenViewed = "screen_viewed"
    public static let buttonTapped = "button_tapped"
    public static let errorOccurred = "error_occurred"
}

// MARK: - Common Properties

/// Standard event property keys.
public enum StandardProperty {
    public static let userId = "user_id"
    public static let sessionId = "session_id"
    public static let timestamp = "timestamp"
    public static let screenName = "screen_name"
    public static let errorCode = "error_code"
    public static let errorMessage = "error_message"
    public static let value = "value"
}
