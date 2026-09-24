import Foundation

/// Defines the strategy for retrying failed operations
public enum SKRetryPolicy: Sendable {
    /// Retry immediately without any delay
    case immediate
    
    /// Retry after a constant delay
    case constant(delay: SKTaskDuration)
    
    /// Retry with exponential backoff
    /// - Parameters:
    ///   - initialDelay: The delay for the first retry
    ///   - multiplier: The multiplier for each subsequent retry
    case exponential(initialDelay: SKTaskDuration = .seconds(1), multiplier: Double = 2.0)
    
    /// Custom retry policy with a closure to calculate delay for each attempt
    case custom(@Sendable (Int) -> SKTaskDuration?)
    
    /// Calculates the delay for a specific attempt
    /// - Parameter attempt: The current attempt number (starting from 1)
    /// - Returns: The duration to wait before the next attempt, or nil to stop retrying
    public func delay(forAttempt attempt: Int) -> SKTaskDuration? {
        switch self {
        case .immediate:
            return .now
        case .constant(let delay):
            return delay
        case .exponential(let initialDelay, let multiplier):
            let delaySeconds = initialDelay.asTimeInterval * pow(multiplier, Double(attempt - 1))
            return SKTaskDuration(delaySeconds)
        case .custom(let closure):
            return closure(attempt)
        }
    }
}
