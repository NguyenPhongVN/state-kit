import Foundation

// MARK: - Task Duration Enum
/// Enumeration representing different time durations for task operations
/// This enum provides a type-safe way to specify time intervals with various units
public enum SCTaskDuration: Comparable, Sendable {
    case never
    case now
    case nanoseconds(UInt64)
    case milliseconds(UInt64)
    case seconds(UInt64)
    case minutes(UInt64)
    case hours(UInt64)
    
    /// Initializes a TaskDuration from a TimeInterval (seconds)
    /// - Parameter seconds: The time interval in seconds
    ///
    /// ## Usage Examples:
    /// ```swift
    /// let duration = TaskDuration(5.5) // 5.5 seconds
    /// let shortDuration = TaskDuration(0.001) // 1 millisecond
    /// ```
    public init(_ seconds: TimeInterval) {
        self = .nanoseconds(UInt64(seconds * 1_000_000_000))
    }
    
    /// Converts the duration to TimeInterval (seconds)
    /// - Returns: The duration in seconds as a TimeInterval
    ///
    /// ## Usage Examples:
    /// ```swift
    /// let duration = TaskDuration.seconds(5)
    /// let seconds = duration.asTimeInterval // 5.0
    ///
    /// let millis = TaskDuration.milliseconds(500)
    /// let seconds = millis.asTimeInterval // 0.5
    /// ```
    public var asTimeInterval: TimeInterval {
        switch self {
            case .never:
                Double.nan
            case .now:
                0
            case let .nanoseconds(nanoseconds):
                Double(nanoseconds) / 1_000_000_000
            case let .milliseconds(milliseconds):
                Double(milliseconds) / 1_000
            case let .seconds(seconds):
                Double(seconds)
            case let .minutes(minutes):
                Double(minutes * 60)
            case let .hours(hours):
                Double(hours * 60 * 60)
        }
    }
    
    /// Converts the duration to milliseconds
    /// - Returns: The duration in milliseconds as UInt64
    ///
    /// ## Usage Examples:
    /// ```swift
    /// let duration = TaskDuration.seconds(1)
    /// let millis = duration.asMilliseconds // 1000
    ///
    /// let shortDuration = TaskDuration.milliseconds(500)
    /// let millis = shortDuration.asMilliseconds // 500
    /// ```
    public var asMilliseconds: UInt64 {
        switch self {
            case .never:
                UInt64.max
            case .now:
                0
            case let .nanoseconds(nanoseconds):
                nanoseconds / 1_000_000
            case let .milliseconds(milliseconds):
                milliseconds
            case let .seconds(seconds):
                seconds * 1_000
            case let .minutes(minutes):
                minutes * 60 * 1_000
            case let .hours(hours):
                hours * 60 * 60 * 1_000
        }
    }
    
    /// Converts the duration to nanoseconds
    /// - Returns: The duration in nanoseconds as UInt64
    ///
    /// ## Usage Examples:
    /// ```swift
    /// let duration = TaskDuration.seconds(1)
    /// let nanos = duration.asNanoseconds // 1_000_000_000
    ///
    /// let shortDuration = TaskDuration.milliseconds(1)
    /// let nanos = shortDuration.asNanoseconds // 1_000_000
    /// ```
    public var asNanoseconds: UInt64 {
        switch self {
            case .never:
                UInt64.max
            case .now:
                0
            case let .nanoseconds(nanoseconds):
                nanoseconds
            case let .milliseconds(milliseconds):
                milliseconds * 1_000_000
            case let .seconds(seconds):
                seconds * 1_000_000_000
            case let .minutes(minutes):
                minutes * 60 * 1_000_000_000
            case let .hours(hours):
                hours * 60 * 60 * 1_000_000_000
        }
    }
    
    /// Adds two TaskDuration values
    /// - Parameters:
    ///   - lhs: Left-hand side duration
    ///   - rhs: Right-hand side duration
    /// - Returns: Sum of the durations, or .never if overflow occurs
    public static func + (lhs: SCTaskDuration, rhs: SCTaskDuration) -> SCTaskDuration {
        let (nanoseconds, didOverflow): (UInt64, Bool) = lhs.asNanoseconds.addingReportingOverflow(rhs.asNanoseconds)
        return didOverflow ? .never : .nanoseconds(nanoseconds)
    }
    
    /// Subtracts two TaskDuration values
    /// - Parameters:
    ///   - lhs: Left-hand side duration
    ///   - rhs: Right-hand side duration
    /// - Returns: Difference of the durations, or .now if underflow occurs
    public static func - (lhs: SCTaskDuration, rhs: SCTaskDuration) -> SCTaskDuration {
        let (nanoseconds, didOverflow): (UInt64, Bool) = lhs.asNanoseconds.subtractingReportingOverflow(rhs.asNanoseconds)
        return didOverflow ? .now : .nanoseconds(nanoseconds)
    }
    
    /// Compares two TaskDuration values
    /// - Parameters:
    ///   - lhs: Left-hand side duration
    ///   - rhs: Right-hand side duration
    /// - Returns: true if lhs is less than rhs
    public static func < (lhs: SCTaskDuration, rhs: SCTaskDuration) -> Bool {
        lhs.asNanoseconds < rhs.asNanoseconds
    }
    
    /// Compares two TaskDuration values for equality
    /// - Parameters:
    ///   - lhs: Left-hand side duration
    ///   - rhs: Right-hand side duration
    /// - Returns: true if the durations are equal
    public static func == (lhs: SCTaskDuration, rhs: SCTaskDuration) -> Bool {
        lhs.asNanoseconds == rhs.asNanoseconds
    }
}

// MARK: - Task Duration Utility Functions
/// Utility functions for working with TaskDuration values

/// Returns the minimum of two TaskDuration values
/// - Parameters:
///   - a: First duration
///   - b: Second duration
/// - Returns: The smaller duration
func min(_ a: SCTaskDuration, _ b: SCTaskDuration) -> SCTaskDuration {
    a.asNanoseconds <= b.asNanoseconds ? a : b
}

/// Returns the maximum of two TaskDuration values
/// - Parameters:
///   - a: First duration
///   - b: Second duration
/// - Returns: The larger duration
func max(_ a: SCTaskDuration, _ b: SCTaskDuration) -> SCTaskDuration {
    a.asNanoseconds <= b.asNanoseconds ? a : b
}
