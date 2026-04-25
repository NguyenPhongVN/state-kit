import StateKit

/// An async, throwing atom that produces an `AsyncPhase<TaskSuccess>`.
///
/// Use `SKThrowingTaskAtom` for async work that can fail. The atom starts at
/// `.loading`, then transitions to `.success(result)` or `.failure(error)`.
///
/// For non-throwing async work, prefer `SKTaskAtom`.
///
/// ## Defining a throwing atom
///
/// ```swift
/// struct ProfileAtom: SKThrowingTaskAtom, Hashable {
///     typealias TaskSuccess = Profile   // required in Swift 6.3 — see SKAtom docs
///     let userID: String
///
///     func task(context: SKAtomTransactionContext) async throws -> Profile {
///         try await APIClient.fetchProfile(id: userID)
///     }
/// }
/// ```
///
/// ## Using it in a view
///
/// ```swift
/// struct ProfileView: View {
///     @SKTask(ProfileAtom(userID: "abc")) var phase
///
///     var body: some View {
///         switch phase {
///         case .loading:          ProgressView()
///         case .success(let p):   Text(p.bio)
///         case .failure(let e):   Text(e.localizedDescription).foregroundStyle(.red)
///         case .idle:             EmptyView()
///         }
///     }
/// }
/// ```
public protocol SKThrowingTaskAtom: SKAsyncPhaseAtom {
    /// Performs the async, potentially throwing work and returns the result.
    ///
    /// - Parameter context: A transaction context. Call `context.read(_:)` to
    ///   access atom values without dependency tracking.
    /// - Throws: Any error that surfaces as `.failure(error)` in the phase.
    @MainActor
    func task(context: SKAtomTransactionContext) async throws -> TaskSuccess
}

extension SKThrowingTaskAtom {
    public func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value> {
        MainActor.assumeIsolated { store.throwingTaskBox(for: self) }
    }
}
