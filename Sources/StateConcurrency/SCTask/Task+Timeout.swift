import Foundation

fileprivate func withThrowingTimeout<T: Sendable>(
    _ timeout: SCTaskDuration,
    operation: sending @escaping @isolated(any) () async throws -> T,
    isolation: isolated (any Actor)? = #isolation
) async throws -> T {
    let task = Task(operation: operation)
    
    var timeoutTask: Task<Void, any Error>?
    
    if timeout < .never {
        guard timeout > .now else {
            task.cancel()
            throw SCTimeoutError(timeout.asTimeInterval)
        }
        
        timeoutTask = Task {
            defer { task.cancel() }
            try await Task.sleep(duration: timeout)
            throw SCTimeoutError(timeout.asTimeInterval)
        }
    }
    
    let result = await withTaskCancellationHandler {
        await task.result
    } onCancel: {
        task.cancel()
    }
    
    if let timeoutTask {
        timeoutTask.cancel()
        
        if case let .failure(error) = await timeoutTask.result, error is SCTimeoutError {
            throw error
        }
    }
    
    return try result.get()
}

extension Task where Success == Never, Failure == Never {
    /// Executes an operation with a timeout
    /// - Parameters:
    ///   - timeout: The maximum time to wait for the operation
    ///   - operation: The operation to execute
    /// - Returns: The result of the operation
    /// - Throws: TimeoutError if the operation times out
    ///
    /// ## Usage Examples:
    /// ```swift
    /// // Execute with 5 second timeout
    /// let result = try await Task.throwingTimeout(.seconds(5)) {
    ///     try await slowOperation()
    /// }
    ///
    /// // Execute with 1 minute timeout
    /// let result = try await Task.throwingTimeout(.minutes(1)) {
    ///     try await downloadLargeFile()
    /// }
    /// ```
    public static func throwingTimeout<T: Sendable>(
        _ timeout: SCTaskDuration,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTimeout(timeout, operation: operation)
    }
}

