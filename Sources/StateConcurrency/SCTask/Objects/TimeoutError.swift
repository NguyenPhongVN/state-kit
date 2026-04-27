import Foundation

/// A custom error type that represents a timeout condition for Swift tasks.
///
/// `SCTimeoutError` is thrown when a task exceeds its specified timeout duration.
/// It provides detailed information about the timeout, including the duration and
/// the location where the timeout occurred in the source code.
///
/// ## Usage Examples
///
/// ### Basic Usage
/// ```swift
/// do {
///     let result = try await someAsyncOperation.timeout(after: 5.0)
///     print("Operation completed: \(result)")
/// } catch let error as SCTimeoutError {
///     print("Operation timed out after \(error.seconds) seconds")
///     print("Timeout occurred at \(error.fileID):\(error.line)")
/// }
/// ```
///
/// ### With Task.timeout Extension
/// ```swift
/// let result = await Task {
///     try await networkCall()
/// }.timeout(after: 10.0) // Will throw SCTimeoutError if it takes longer than 10 seconds
/// ```
///
/// ### Custom Timeout Handling
/// ```swift
/// func performOperationWithRetry() async throws -> String {
///     do {
///         return try await slowOperation().timeout(after: 3.0)
///     } catch is SCTimeoutError {
///         print("First attempt timed out, retrying...")
///         return try await slowOperation().timeout(after: 5.0)
///     }
/// }
/// ```
public struct SCTimeoutError: Error, CustomDebugStringConvertible {

    /// The timeout duration in seconds that was exceeded.
    public let seconds: TimeInterval
    
    /// The file identifier where the timeout error was created.
    /// This helps with debugging by identifying the source location.
    public let fileID: String
    
    /// The line number where the timeout error was created.
    /// This helps with debugging by identifying the exact source location.
    public let line: UInt
    
    /// Creates a new timeout error with the specified duration and source location.
    ///
    /// - Parameters:
    ///   - seconds: The timeout duration in seconds that was exceeded
    ///   - fileID: The file identifier where the timeout occurred (defaults to `#fileID`)
    ///   - line: The line number where the timeout occurred (defaults to `#line`)
    ///
    /// ## Example
    /// ```swift
    /// // Automatically captures current file and line
    /// let error = SCTimeoutError(5.0)
    ///
    /// // Or specify custom location
    /// let error = SCTimeoutError(10.0, fileID: "MyFile.swift", line: 42)
    /// ```
    public init(
        _ seconds: TimeInterval,
        fileID: String = #fileID,
        line: UInt = #line
    ) {
        self.seconds = seconds
        self.fileID = fileID
        self.line = line
    }
    
    /// A human-readable description of the timeout error.
    ///
    /// This description includes the timeout duration, file location, and line number
    /// to help with debugging and identifying where the timeout occurred.
    ///
    /// ## Example Output
    /// ```
    /// "Task timed out before completion. Timeout: 5.0 seconds. Location: MyFile.swift:42"
    /// ```
    public var debugDescription: String {
        "Task timed out before completion. Timeout: \(seconds) seconds. Location: \(fileID):\(line)"
    }
}
