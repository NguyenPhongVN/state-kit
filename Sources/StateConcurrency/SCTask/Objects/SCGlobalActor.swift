import Foundation

/// A global actor that serializes access to shared mutable state.
///
/// `PerformerActor` provides a global actor that can be used to isolate shared mutable state
/// and ensure thread-safe access across your application. It's particularly useful for
/// coordinating async operations and managing state that needs to be accessed from multiple
/// concurrent contexts.
///
/// ## Usage Example:
/// ```swift
/// @PerformerActor
/// var sharedState: Int = 0
///
/// @PerformerActor
/// func updateState() {
///     sharedState += 1
/// }
/// ```
@globalActor
actor SCGlobalActor {
    static let shared = SCGlobalActor()
}

/// A thread-safe reference to a `Task` that can be stored and cancelled.
///
/// `TaskReference` provides a `Sendable`-conforming wrapper around a `Task<Void, Never>`
/// that uses `PerformerActor` to ensure thread-safe access. This is useful when you need
/// to store a task reference and potentially cancel it from different concurrent contexts.
///
/// ## Usage Example:
/// ```swift
/// let taskRef = TaskReference()
///
/// // Store a task
/// let task = Task {
///     await performLongRunningOperation()
/// }
/// await taskRef.set(task)
///
/// // Cancel it later from anywhere
/// await taskRef.cancel()
/// ```
final class TaskReference: Sendable {
    typealias Wrapped = Task<Void, Never>

    @SCGlobalActor
    var wrapped: Wrapped?

    /// Sets the wrapped task.
    ///
    /// - Parameter task: The task to store, or `nil` to clear the reference.
    @SCGlobalActor
    func set(_ task: Wrapped?) {
        wrapped = task
    }

    /// Cancels the wrapped task if one exists.
    ///
    /// This method is safe to call even if no task is currently stored.
    @SCGlobalActor
    func cancel() {
        wrapped?.cancel()
    }
}

/// A thread-safe mechanism to ensure an operation is performed exactly once.
///
/// `OncePerformer` uses `PerformerActor` to guarantee that a given operation is executed
/// only one time, even when called from multiple concurrent contexts. This is useful for
/// one-time initialization, cleanup operations, or ensuring idempotent behavior.
///
/// ## Usage Example:
/// ```swift
/// let performer = OncePerformer()
///
/// // Called from multiple places concurrently
/// Task {
///     await performer.perform {
///         print("This will only print once")
///         setupResources()
///     }
/// }
///
/// Task {
///     await performer.perform {
///         print("This will never execute")
///     }
/// }
/// ```
///
/// ## Common Use Cases:
/// - **Initialization**: Ensure setup code runs only once
/// - **Cleanup**: Guarantee teardown happens exactly once
/// - **Event Handlers**: Prevent duplicate event processing
/// - **Resource Management**: One-time resource allocation
final class OncePerformer: Sendable {
    @SCGlobalActor
    var performed = false

    /// Performs the given operation exactly once.
    ///
    /// If this method is called multiple times, only the first call will execute
    /// the operation. Subsequent calls will return immediately without executing
    /// the operation.
    ///
    /// - Parameter operation: The operation to perform once. Must be `@Sendable`.
    @SCGlobalActor
    func perform(_ operation: @Sendable () -> Void) {
        guard !performed else { return }
        defer { performed = true }
        operation()
    }
}
