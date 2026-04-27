import Foundation

extension Task where Success == Never, Failure == Never {
    /// Executes multiple operations concurrently and gathers their results.
    ///
    /// This method uses a `TaskGroup` to execute the provided operations in parallel.
    /// It returns an array of `Result` objects, one for each operation, in the order
    /// they were provided. If an operation fails, its error is captured in the
    /// corresponding `Result.failure`, but it does not stop other operations.
    ///
    /// - Parameters:
    ///   - operations: An array of operations to execute.
    ///   - maxConcurrentTasks: Optional limit on the number of concurrently executing tasks.
    /// - Returns: An array of results from the operations.
    public static func gather<T: Sendable>(
        _ operations: [@Sendable () async throws -> T],
        maxConcurrentTasks: Int? = nil
    ) async -> [Result<T, Error>] {
        let limiter = maxConcurrentTasks.map { SCConcurrencyLimiter(maxConcurrentTasks: $0) }
        
        return await withTaskGroup(of: (Int, Result<T, Error>).self) { group in
            for (index, operation) in operations.enumerated() {
                group.addTask {
                    do {
                        let value: T
                        if let limiter = limiter {
                            value = try await limiter.execute { try await operation() }
                        } else {
                            value = try await operation()
                        }
                        return (index, .success(value))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            var results = [Result<T, Error>?](repeating: nil, count: operations.count)
            for await (index, result) in group {
                results[index] = result
            }
            
            return results.compactMap { $0 }
        }
    }
    
    /// Executes multiple operations concurrently and returns their values.
    /// Throws an error if any operation fails.
    ///
    /// - Parameters:
    ///   - operations: An array of operations to execute.
    ///   - maxConcurrentTasks: Optional limit on the number of concurrently executing tasks.
    /// - Returns: An array of values from the operations.
    public static func gatherThrowing<T: Sendable>(
        _ operations: [@Sendable () async throws -> T],
        maxConcurrentTasks: Int? = nil
    ) async throws -> [T] {
        let results = await gather(operations, maxConcurrentTasks: maxConcurrentTasks)
        return try results.map { try $0.get() }
    }
    
    /// Executes multiple operations concurrently and returns only the successful values.
    /// Failed operations are silently ignored.
    ///
    /// - Parameters:
    ///   - operations: An array of operations to execute.
    ///   - maxConcurrentTasks: Optional limit on the number of concurrently executing tasks.
    /// - Returns: An array of successful values.
    public static func gatherValues<T: Sendable>(
        _ operations: [@Sendable () async throws -> T],
        maxConcurrentTasks: Int? = nil
    ) async -> [T] {
        let results = await gather(operations, maxConcurrentTasks: maxConcurrentTasks)
        return results.compactMap { try? $0.get() }
    }
}
