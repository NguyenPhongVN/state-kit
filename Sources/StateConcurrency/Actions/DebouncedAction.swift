import Foundation
import ConcurrencyExtras

/// A sendable, debounced action wrapper that delays execution of an async operation.
///
/// Each call to the action cancels any pending execution and reschedules it after the
/// specified interval. Only the last call "wins" — intermediate invocations are dropped.
///
/// ── Example ──────────────────────────────────────────────────────────
///   let search = DebouncedAction(interval: .milliseconds(300)) { query in
///       let results = await api.search(query)
///       await updateUI(results)
///   }
///
///   await search("a")   // cancelled after 50ms
///   await search("ab")  // cancelled after 50ms
///   await search("abc") // executes after 300ms of no further calls
///
/// ## Thread Safety
/// The internal `Task` reference is protected by `LockIsolated`, making this safe to
/// call from any actor or task context.
public final class DebouncedAction<each Input: Sendable>: Sendable {
    private let interval: Duration
    private let operation: @Sendable (repeat each Input) async -> Void
    private let task = LockIsolated<Task<Void, Never>?>(nil)
    /// Serializes the cancel→create→store sequence so two concurrent calls can
    /// never both leave a scheduled task alive.
    private let stateLock = NSLock()

    /// Creates a debounced action.
    /// - Parameters:
    ///   - interval: The minimum delay between the last call and actual execution.
    ///   - operation: The async operation to debounce.
    public init(interval: Duration, operation: @escaping @Sendable (repeat each Input) async -> Void) {
        self.interval = interval
        self.operation = operation
    }

    /// Invoke the debounced action.
    /// - Parameter args: The arguments to pass to the operation.
    public func callAsFunction(_ args: repeat each Input) {
        // The cancel→create→store sequence must be atomic: two concurrent calls
        // could otherwise each cancel the stale task AFTER the other stored
        // theirs, letting both scheduled tasks run the operation.
        stateLock.lock()
        defer { stateLock.unlock() }
        task.withValue { $0?.cancel() }
        let newTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            await operation(repeat each args)
        }
        task.withValue { $0 = newTask }
    }
}
