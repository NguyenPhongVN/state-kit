import Foundation
// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    /// Creates a task that executes the given operation and returns a `Result` instead of throwing.
    ///
    /// This method is useful when you want to handle task results without using try-catch,
    /// particularly with typed throws. Instead of the task throwing an error, it captures
    /// both success and failure cases in a `Result`.
    ///
    /// ## Usage Example:
    /// ```swift
    /// enum FetchError: Error {
    ///     case networkFailure
    ///     case decodingError
    /// }
    ///
    /// let task = Task<Result<String, FetchError>, Never>.withResult {
    ///     try await fetchUserData()
    /// }
    ///
    /// let result = await task.value
    /// switch result {
    /// case .success(let data):
    ///     print("Got data: \(data)")
    /// case .failure(let error):
    ///     print("Failed with: \(error)")
    /// }
    /// ```
    ///
    /// ## Benefits:
    /// - **No throwing**: The task itself never throws, making it safer to use
    /// - **Type safety**: Works seamlessly with typed throws
    /// - **Result handling**: Natural integration with Result-based APIs
    /// - **Error capture**: All errors are captured in the Result
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. If `nil`, uses the priority from the current context.
    ///   - operation: An async operation that may throw a typed error.
    /// - Returns: A task that returns a `Result<Success, Failure>` and never throws.
    @discardableResult
    public static func withResult<T: Sendable, E: Sendable>(priority: TaskPriority? = nil, operation: sending @escaping @isolated(any) () async throws(E) -> T) -> Task<Result<T, E>, Never> {
        Task<Result<T, E>, Never>(priority: priority) { () async -> Result<T, E> in
            do throws(E) {
                let value = try await operation()
                return .success(value)
            } catch {
                return .failure(error)
            }
        }
    }
}

