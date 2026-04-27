import Foundation

// MARK: - MainActor Extensions

extension MainActor {
    /// Executes an operation on the main actor, running it immediately if already on the main thread.
    ///
    /// This method provides an optimized way to run main-actor-isolated code by avoiding
    /// unnecessary async context switches when already on the main thread. It intelligently
    /// determines the current execution context and chooses the most efficient path.
    ///
    /// ## Behavior:
    /// - **Already on main thread**: Executes immediately using `assumeIsolated`
    /// - **Not on main thread**: Dispatches synchronously to main queue
    ///
    /// ## Usage Examples:
    ///
    /// ### Basic Usage
    /// ```swift
    /// // Update UI from any thread
    /// let result = MainActor.runImmediately {
    ///     // This runs on main thread
    ///     label.text = "Updated"
    ///     return label.text
    /// }
    /// ```
    ///
    /// ### With Error Handling
    /// ```swift
    /// do {
    ///     let data = try MainActor.runImmediately {
    ///         guard let data = viewModel.getData() else {
    ///             throw DataError.notFound
    ///         }
    ///         return data
    ///     }
    /// } catch {
    ///     print("Error: \(error)")
    /// }
    /// ```
    ///
    /// ### Performance Optimization
    /// ```swift
    /// // Avoid unnecessary async overhead when already on main thread
    /// func updateUI() {
    ///     MainActor.runImmediately {
    ///         // If called from main thread, runs immediately
    ///         // If called from background, dispatches to main
    ///         self.refreshView()
    ///     }
    /// }
    /// ```
    ///
    /// ## When to Use:
    /// - ✅ Need synchronous execution on main thread
    /// - ✅ Want to avoid async overhead when already on main thread
    /// - ✅ Need to return a value from main-actor-isolated code
    /// - ✅ Updating UI from potentially any thread
    ///
    /// ## When NOT to Use:
    /// - ❌ Long-running operations (will block the calling thread)
    /// - ❌ When async execution is acceptable
    /// - ❌ Inside already main-actor-isolated contexts (just call directly)
    ///
    /// - Parameters:
    ///   - operation: A closure that executes on the main actor and may throw errors.
    ///   - file: The file where this method is called (for debugging).
    ///   - line: The line where this method is called (for debugging).
    /// - Returns: The value returned by the operation closure.
    /// - Throws: Any error thrown by the operation closure.
    public static func runImmediately<T: Sendable>(
        _ operation: @MainActor () throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) rethrows -> T {
        if Thread.isMainThread {
            // Execute immediately if already on the main thread.
            return try MainActor.assumeIsolated(
                { try operation() },
                file: file,
                line: line
            )
        }
        
        // Otherwise, dispatch synchronously to the main queue.
        return try DispatchQueue.main.sync {
            try operation()
        }
    }
}
