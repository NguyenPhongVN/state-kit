import Foundation

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension SCTaskDuration {
    /// Initializes a SCTaskDuration from a native Swift Duration
    /// - Parameter duration: The native Swift duration
    public init(_ duration: Swift.Duration) {
        let nanoseconds = duration.components.seconds * 1_000_000_000 + (duration.components.attoseconds / 1_000_000_000)
        self = .nanoseconds(UInt64(nanoseconds))
    }
    
    /// Converts the SCTaskDuration to a native Swift Duration
    public var asDuration: Swift.Duration {
        switch self {
        case .never:
            return .seconds(Int64.max)
        case .now:
            return .zero
        case .nanoseconds(let nanoseconds):
            return .nanoseconds(Int64(nanoseconds))
        case .milliseconds(let milliseconds):
            return .milliseconds(Int64(milliseconds))
        case .seconds(let seconds):
            return .seconds(Int64(seconds))
        case .minutes(let minutes):
            return .seconds(Int64(minutes * 60))
        case .hours(let hours):
            return .seconds(Int64(hours * 3600))
        }
    }
}
