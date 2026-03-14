/// Asynchronous state used by `useAsync`.
///
/// This models the typical lifecycle of an async operation:
/// - `idle`:     the operation has not started yet.
/// - `loading`:  the operation is currently running.
/// - `success`:  the operation finished successfully and produced a value.
/// - `failure`:  the operation failed with an error.
public enum AsyncPhase<Value> {
    /// The async operation has not started yet.
    case idle
    /// The async operation is currently running.
    case loading
    /// The async operation finished successfully with a value.
    case success(Value)
    /// The async operation failed with an error.
    case failure(Error)
}
