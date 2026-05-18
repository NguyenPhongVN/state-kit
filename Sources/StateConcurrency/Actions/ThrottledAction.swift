import Foundation
import ConcurrencyExtras

/// A sendable, throttled action wrapper that limits the execution rate of an async operation.
///
/// Calls within the specified interval from the last execution are silently dropped.
/// Only the first call in each interval window "wins".
///
/// ── Example ──────────────────────────────────────────────────────────
///   let sync = ThrottledAction(interval: .seconds(1)) {
///       await api.syncData()
///   }
///
///   await sync()  // executes immediately
///   await sync()  // ignored (within 1s)
///   await sync()  // ignored (within 1s)
///   // after 1s from first call:
///   await sync()  // executes again
///
/// ## Thread Safety
/// The last-execution timestamp is protected by `LockIsolated`, making this safe to
/// call from any actor or task context.
public final class ThrottledAction<each Input: Sendable>: Sendable {
    private let interval: Duration
    private let operation: @Sendable (repeat each Input) async -> Void
    private let lastExecution = LockIsolated<Date>(.distantPast)

    /// Creates a throttled action.
    /// - Parameters:
    ///   - interval: The minimum interval between executions.
    ///   - operation: The async operation to throttle.
    public init(interval: Duration, operation: @escaping @Sendable (repeat each Input) async -> Void) {
        self.interval = interval
        self.operation = operation
    }

    /// Invoke the throttled action.
    /// - Parameter args: The arguments to pass to the operation.
    public func callAsFunction(_ args: repeat each Input) {
        let now = Date()
        let shouldExecute = lastExecution.withValue { lastExec in
            let elapsed = now.timeIntervalSince(lastExec)
            let intervalSeconds = TimeInterval(interval.components.seconds) + TimeInterval(interval.components.attoseconds) / 1e18
            guard elapsed >= intervalSeconds else { return false }
            lastExec = now
            return true
        }
        guard shouldExecute else { return }
        Task { [weak self] in
            await self?.operation(repeat each args)
        }
    }
}
