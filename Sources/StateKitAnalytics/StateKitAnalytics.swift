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
    public let name: String
    public let timestamp: Date
    public let properties: [String: AnyCodable]
    public let userId: String?
    public let sessionId: String

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
    public let enabled: Bool
    public let flushInterval: TimeInterval
    public let batchSize: Int
    public let persistLocal: Bool
    public let userId: String?
    public let sessionId: String

    public init(
        enabled: Bool = true,
        flushInterval: TimeInterval = 30,
        batchSize: Int = 50,
        persistLocal: Bool = false,
        userId: String? = nil,
        sessionId: String = UUID().uuidString
    ) {
        self.enabled = enabled
        self.flushInterval = max(1, flushInterval)
        self.batchSize = max(1, batchSize)
        self.persistLocal = persistLocal
        self.userId = userId
        self.sessionId = sessionId
    }
}

// MARK: - Analytics Provider Observer

/// Observes provider changes and records as analytics events.
public struct AnalyticsProviderObserver: ProviderObserver & Sendable {
    private let tracker: EventTracker
    private let includeValues: Bool

    public init(tracker: EventTracker, includeValues: Bool = false) {
        self.tracker = tracker
        self.includeValues = includeValues
    }

    /// Observes provider state change.
    public func onChange<T: Sendable>(
        provider: any ProviderProtocol,
        newValue: T,
        previousValue: T?
    ) {
        let event = AnalyticsEvent(
            name: "state_changed",
            properties: [
                "provider": .string(String(describing: provider)),
                "includes_value": .bool(includeValues),
            ]
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
