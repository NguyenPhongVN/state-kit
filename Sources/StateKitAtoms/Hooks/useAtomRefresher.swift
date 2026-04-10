import StateKit

// MARK: - useAtomRefresher

/// Returns an async closure that cancels the current task for a
/// `SKTaskAtom`, resets its phase to `.loading`, then awaits the new result.
///
/// Use this inside `Button` actions or gesture handlers to manually retry or
/// pull-to-refresh an async atom.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`.
///
/// ```swift
/// struct PostsView: StateView {
///     var stateBody: some View {
///         let phase    = useAtomValue(PostsAtom())
///         let refresh  = useAtomRefresher(PostsAtom())
///
///         Group {
///             switch phase {
///             case .loading:         ProgressView()
///             case .success(let ps): PostList(posts: ps)
///             case .idle, .failure:  EmptyView()
///             }
///         }
///         .toolbar {
///             Button("Refresh") {
///                 Task { await refresh() }
///             }
///         }
///     }
/// }
/// ```
///
/// - Parameter atom: The non-throwing task atom to refresh.
/// - Returns: An `@MainActor async` closure that performs the refresh.
@MainActor
public func useAtomRefresher<A: SKTaskAtom>(_ atom: A) -> @MainActor () async -> Void {
    let store = useEnvironment(\.skAtomStore)
    return { @MainActor in
        await store.refreshTask(for: atom)
    }
}

/// Returns an async closure that cancels the current task for a
/// `SKThrowingTaskAtom`, resets its phase to `.loading`, then awaits the
/// new result (which may transition to `.failure` on error).
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`.
///
/// ```swift
/// struct ProfileView: StateView {
///     var stateBody: some View {
///         let phase   = useAtomValue(ProfileAtom(id: "abc"))
///         let refresh = useAtomRefresher(ProfileAtom(id: "abc"))
///
///         switch phase {
///         case .loading:        ProgressView()
///         case .success(let p): Text(p.bio)
///         case .failure(let e): VStack {
///             Text(e.localizedDescription)
///             Button("Retry") { Task { await refresh() } }
///         }
///         case .idle: EmptyView()
///         }
///     }
/// }
/// ```
///
/// - Parameter atom: The throwing task atom to refresh.
/// - Returns: An `@MainActor async` closure that performs the refresh.
@MainActor
public func useAtomRefresher<A: SKThrowingTaskAtom>(_ atom: A) -> @MainActor () async -> Void {
    let store = useEnvironment(\.skAtomStore)
    return { @MainActor in
        await store.refreshThrowingTask(for: atom)
    }
}
