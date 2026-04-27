/// Returns the current success value from `phase`, or the last success value
/// seen in a previous render.
///
/// This is useful for stale-while-revalidate UI, where the screen should keep
/// showing the last loaded content while a new request is loading or after a
/// later request fails.
///
/// Behavior:
/// - Before any success has occurred, the helper returns `nil`.
/// - When `phase` becomes `.success(value)`, that value is cached and
///   returned.
/// - On later `.loading`, `.failure`, or `.idle` states, the cached success
///   value is returned instead of `nil`.
///
/// - Parameter phase: The async phase to inspect.
/// - Returns: The current success value, or the last successful value. Returns
///   `nil` until the first success arrives.
///
/// ### Example
/// ```swift
/// struct ProfileView: StateView {
///     let phase: AsyncPhase<Profile>
///
///     var stateBody: some View {
///         let profile = useLastValueAsyncPhase(phase)
///
///         switch phase {
///         case .idle:
///             Text("Ready")
///         case .loading:
///             if let profile {
///                 ProfileContent(profile)
///             } else {
///                 ProgressView()
///             }
///         case .success(let profile):
///             ProfileContent(profile)
///         case .failure(let error):
///             if let profile {
///                 ProfileContent(profile)
///             } else {
///                 Text(error.localizedDescription)
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func useLastValueAsyncPhase<Value>(
    _ phase: AsyncPhase<Value>
) -> Value? {
    useLastSuccessAsyncPhase(phase).value
}

/// Returns the current phase until the first success arrives, then keeps
/// returning the last successful phase across later non-success transitions.
///
/// This is useful when the UI should continue to work with the full success
/// phase — not just the success value — while a later request is loading or
/// has failed.
///
/// Behavior:
/// - Before any success has occurred, the helper returns `phase` unchanged.
/// - When `phase` becomes `.success(value)`, that entire phase is cached and
///   returned.
/// - On later `.loading`, `.failure`, or `.idle` states, the cached success
///   phase is returned instead of the current non-success phase.
///
/// - Parameter phase: The async phase to inspect.
/// - Returns: The current phase until the first success, then the last
///   successful phase.
///
/// ### Example
/// ```swift
/// struct ProfileView: StateView {
///     let phase: AsyncPhase<Profile>
///
///     var stateBody: some View {
///         let displayPhase = useLastSuccessAsyncPhase(phase)
///
///         switch displayPhase {
///         case .idle:
///             Text("Ready")
///         case .loading:
///             ProgressView()
///         case .success(let profile):
///             ProfileContent(profile)
///         case .failure(let error):
///             Text(error.localizedDescription)
///         }
///     }
/// }
/// ```
@MainActor
public func useLastSuccessAsyncPhase<Value>(
    _ phase: AsyncPhase<Value>
) -> AsyncPhase<Value> {
    @HRef var storePhase: AsyncPhase<Value> = phase

    if case .success = phase {
        storePhase = phase
        return phase
    }

    return storePhase
}
