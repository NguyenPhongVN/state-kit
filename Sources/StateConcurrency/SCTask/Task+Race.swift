import Foundation

extension Task where Success == Never, Failure == Never {
    /// Executes multiple operations concurrently and returns the result of the first one to complete.
    ///
    /// The remaining operations are cancelled as soon as the first one finishes successfully
    /// or all of them fail.
    ///
    /// - Parameter operations: An array of operations to race.
    /// - Returns: The result of the first operation to finish successfully.
    /// - Throws: The error of the last failed operation if all operations fail.
    public static func race<T: Sendable>(
        _ operations: [@Sendable () async throws -> T]
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            for operation in operations {
                group.addTask {
                    try await operation()
                }
            }
            
            var lastError: (any Error)?
            
            // Wait for the first successful result
            while let result = await group.nextResult() {
                switch result {
                case .success(let value):
                    group.cancelAll()
                    return value
                case .failure(let error):
                    lastError = error
                }
            }
            
            if let lastError {
                throw lastError
            }
            
            throw NSError(domain: "SCTask", code: 0, userInfo: [NSLocalizedDescriptionKey: "No operations to race"])
        }
    }
}
