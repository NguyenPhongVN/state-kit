import Foundation

// MARK: - Task Extensions
/// Extensions for Task providing convenient async operations

extension Task where Success == Never, Failure == Never {
    /// Sleeps for the specified duration
    /// - Parameter value: The duration to sleep for
    /// - Throws: CancellationError if the task is cancelled
    ///
    /// ## Usage Examples:
    /// ```swift
    /// // Sleep for 1 second
    /// try await Task.sleep(duration: .seconds(1))
    ///
    /// // Sleep for 500 milliseconds
    /// try await Task.sleep(duration: .milliseconds(500))
    ///
    /// // Sleep for 100 nanoseconds
    /// try await Task.sleep(duration: .nanoseconds(100))
    /// ```
     public static func sleep(duration value: SCTaskDuration) async throws {
        try await Task.sleep(nanoseconds: value.asNanoseconds)
    }
    
     public static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(duration: SCTaskDuration(seconds))
    }
}
