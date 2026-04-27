import Foundation

fileprivate func withTaskCancellationWithError<T: Sendable>(
    _ onCancelError: any Error,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    let task = TaskReference()
    let once = OncePerformer()
    return try await withTaskCancellationHandler(operation: { @SCGlobalActor in
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            guard !Task.isCancelled else {
                continuation.resume(throwing: onCancelError)
                return
            }
            
            let _task = Task {
                await withTaskCancellationHandler {
                    do {
                        let taskResult = try await operation()
                        once.perform { continuation.resume(returning: taskResult) }
                    } catch {
                        once.perform { continuation.resume(throwing: error) }
                    }
                } onCancel: {
                    Task { @SCGlobalActor in
                        once.perform { continuation.resume(throwing: onCancelError) }
                    }
                }
            }
            
            task.set(_task)
        }
    }, onCancel: {
        Task { @SCGlobalActor in
            task.cancel()
        }
    })
}

extension Task where Success == Never, Failure == Never {
    
    
    /// Executes an operation with custom cancellation error
    /// - Parameters:
    ///   - onCancelError: The error to throw when cancelled
    ///   - operation: The operation to execute
    /// - Returns: The result of the operation
    /// - Throws: The specified error if the operation is cancelled
    ///
    /// ## Usage Examples:
    /// ```swift
    /// // Execute with custom cancellation error
    /// let result = try await Task.withTaskCancellationWithError(
    ///     CustomError.operationCancelled
    /// ) {
    ///     try await longRunningOperation()
    /// }
    /// ```
    public static func cancellationWithError<T: Sendable>(
        _ onCancelError: any Error,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withTaskCancellationWithError(onCancelError, operation: operation)
    }
}
