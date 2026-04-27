import StateKit

/// Shared implementation for the public "seen status" helpers.
///
/// The first time `phase.status` matches `status`, the helper stores that
/// status in a ref and keeps returning it on later renders. Before that first
/// match happens, it returns `nil`.
@MainActor
private func _seenSKStatus<Value>(
    _ status: SKStatus,
    in phase: AsyncPhase<Value>
) -> SKStatus? {
    /// Stores the target status after it has appeared once.
    @HRef var storedStatus: SKStatus? = nil

    if storedStatus == nil, phase.status == status {
        storedStatus = status
    }

    return storedStatus
}

/// Returns `status` once `phase` has reached that status at least once.
///
/// This helper remembers whether a specific `SKStatus` has ever appeared in
/// the given `AsyncPhase`. Before the target status appears, it returns `nil`.
/// As soon as `phase.status == status` in any render, the status is cached and
/// continues to be returned on later renders.
///
/// This is useful when later UI behavior depends on whether a lifecycle event
/// has already happened at least once, such as:
/// - whether loading has ever started
/// - whether a request has ever succeeded
/// - whether a request has ever failed
///
/// - Parameters:
///   - status: The status to watch for.
///   - phase: The async phase whose status history should be tracked.
/// - Returns: `status` after it has been seen at least once; otherwise `nil`.
///
/// ### Example
/// ```swift
/// struct ProfileView: StateView {
///     let phase: AsyncPhase<Profile>
///
///     var stateBody: some View {
///         let seenFailure = useSeenSKStatus(.failure, in: phase)
///
///         VStack {
///             if seenFailure != nil {
///                 Text("This request has failed before.")
///             }
///
///             switch phase {
///             case .idle:
///                 Text("Ready")
///             case .loading:
///                 ProgressView()
///             case .success(let profile):
///                 Text(profile.name)
///             case .failure(let error):
///                 Text(error.localizedDescription)
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func useSeenSKStatus<Value>(
    _ status: SKStatus,
    in phase: AsyncPhase<Value>
) -> SKStatus? {
    _seenSKStatus(status, in: phase)
}

/// Returns `true` once `phase` has reached `status` at least once.
///
/// This is a Boolean convenience wrapper over `useSeenSKStatus(_:in:)`.
/// Use it when call sites only need a yes/no answer rather than the status
/// value itself.
///
/// - Parameters:
///   - status: The status to watch for.
///   - phase: The async phase whose status history should be tracked.
/// - Returns: `true` after `status` has been seen at least once; otherwise
///   `false`.
///
/// ### Example
/// ```swift
/// struct ProfileView: StateView {
///     let phase: AsyncPhase<Profile>
///
///     var stateBody: some View {
///         let hasSucceeded = useHasSeenSKStatus(.success, in: phase)
///
///         VStack {
///             if hasSucceeded {
///                 Text("At least one successful load has happened.")
///             }
///
///             switch phase {
///             case .idle:
///                 Text("Ready")
///             case .loading:
///                 ProgressView()
///             case .success(let profile):
///                 Text(profile.name)
///             case .failure(let error):
///                 Text(error.localizedDescription)
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func useHasSeenSKStatus<Value>(
    _ status: SKStatus,
    in phase: AsyncPhase<Value>
) -> Bool {
    _seenSKStatus(status, in: phase) != nil
}
