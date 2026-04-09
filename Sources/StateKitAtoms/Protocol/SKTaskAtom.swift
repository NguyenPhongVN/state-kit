import StateKit

/// An async atom that produces an `AsyncPhase<TaskSuccess>`.
///
/// Use `SKTaskAtom` when you need to fetch data or perform async work that
/// cannot throw. The atom immediately returns `.loading` while the task is
/// in-flight, then transitions to `.success(result)` when it completes.
///
/// If the task needs to throw errors, use `SKThrowingTaskAtom` instead.
///
/// ## Defining an async atom
///
/// ```swift
/// struct UserAtom: SKTaskAtom, Hashable {
///     typealias TaskSuccess = User   // required in Swift 6.3 — see SKAtom docs
///     let userID: String
///
///     func task(context: SKAtomTransactionContext) async -> User {
///         await UserService.fetch(id: userID)
///     }
/// }
/// ```
///
/// ## Using it in a view
///
/// ```swift
/// struct UserView: View {
///     @SKTask(UserAtom(userID: "abc")) var phase
///
///     var body: some View {
///         switch phase {
///         case .loading:          ProgressView()
///         case .success(let u):   Text(u.name)
///         case .idle, .failure:   EmptyView()
///         }
///     }
/// }
/// ```
///
/// ## Inline async atom
///
/// ```swift
/// let userAtom = asyncAtom { _ in await UserService.fetch(id: "abc") }
/// ```
public protocol SKTaskAtom: SKAtom where Value == AsyncPhase<TaskSuccess> {
    /// The type of the successful result produced by this atom's task.
    associatedtype TaskSuccess

    /// Performs the async work and returns the result.
    ///
    /// - Parameter context: A transaction context. Call `context.read(_:)` to
    ///   access atom values without creating dependency edges.
    @MainActor
    func task(context: SKAtomTransactionContext) async -> TaskSuccess
}

extension SKTaskAtom {
    public func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value> {
        MainActor.assumeIsolated { store.taskBox(for: self) }
    }
}
