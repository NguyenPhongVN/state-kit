import Foundation

extension Task where Success == Never, Failure == Never {
    /// Creates a task that retries the operation with a specified retry policy
    /// - Parameters:
    ///   - priority: The priority of the task
    ///   - maxRetryCount: Maximum number of retry attempts (default: 3)
    ///   - policy: The retry policy to use (default: .exponential)
    ///   - isRetryingCallback: Callback called when retrying (optional)
    ///   - operation: The operation to retry
    /// - Returns: A task that will retry the operation
    public static func retrying<T: Sendable>(
        priority: TaskPriority? = nil,
        maxRetryCount: Int = 3,
        policy: SCRetryPolicy = .exponential(initialDelay: .seconds(5), multiplier: 1.0),
        isRetryingCallback: (@Sendable (Int) -> Void)? = nil,
        operation: @Sendable @escaping () async throws -> T
    ) -> Task<T, Error> {
        Task<T, Error>(priority: priority) {
            for attempt in 0..<maxRetryCount {
                do {
                    return try await operation()
                } catch {
                    let nextAttempt = attempt + 1
                    isRetryingCallback?(nextAttempt)
                    
                    guard let delay = policy.delay(forAttempt: nextAttempt) else {
                        throw error
                    }
                    
                    try await Task<Never, Never>.sleep(duration: delay)
                    continue
                }
            }
            
            try Task<Never, Never>.checkCancellation()
            return try await operation()
        }
    }
    
    /// Backward compatible retrying method
    @discardableResult
    public static func retrying<T: Sendable>(
        priority: TaskPriority? = nil,
        maxRetryCount: Int = 3,
        retryInterval: SCTaskDuration? = nil,
        isRetryingCallback: (@Sendable (Int) -> Void)? = nil,
        operation: @Sendable @escaping () async throws -> T
    ) -> Task<T, Error> {
        let policy: SCRetryPolicy
        if let retryInterval = retryInterval {
            policy = .constant(delay: retryInterval)
        } else {
            policy = .exponential(initialDelay: .seconds(5), multiplier: 1.0)
        }
        
        return retrying(
            priority: priority,
            maxRetryCount: maxRetryCount,
            policy: policy,
            isRetryingCallback: isRetryingCallback,
            operation: operation
        )
    }
}

