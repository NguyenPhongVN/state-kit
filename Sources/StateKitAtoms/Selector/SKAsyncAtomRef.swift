/// An inline, anonymous non-throwing async atom created by `asyncAtom()`.
///
/// `SKAsyncAtomRef` wraps an async closure and exposes its result as an
/// `AsyncPhase<Success, Never>`. It immediately returns `.loading` and
/// transitions to `.success(value)` when the async work completes.
///
/// Like other `*Ref` types, it uses **reference identity** as its key.
///
/// ## Creating an inline async atom
///
/// ```swift
/// let feedAtom = asyncAtom { _ in
///     await FeedService.loadPosts()
/// }
/// ```
///
/// ## Using in a view
///
/// ```swift
/// @SKTask(feedAtom) var phase
///
/// var body: some View {
///     switch phase {
///     case .loading:        ProgressView()
///     case .success(let p): PostList(posts: p)
///     default:              EmptyView()
///     }
/// }
/// ```
public final class SKAsyncAtomRef<Success>: SKTaskAtom, @unchecked Sendable {

    // MARK: - Storage

    private let _task: @MainActor (SKAtomTransactionContext) async -> Success

    // MARK: - Init

    /// Creates a new anonymous async atom with the given async producer.
    ///
    /// - Parameter task: An async closure that performs work and returns the
    ///   result. Use `context.read(_:)` to access other atoms without creating
    ///   reactive dependencies.
    public init(_ task: @escaping @MainActor (SKAtomTransactionContext) async -> Success) {
        _task = task
    }

    // MARK: - SKTaskAtom

    public func task(context: SKAtomTransactionContext) async -> Success {
        await _task(context)
    }

    // MARK: - Hashable / Equatable (reference identity)

    public static func == (lhs: SKAsyncAtomRef, rhs: SKAsyncAtomRef) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

/// An inline, anonymous throwing async atom created by `throwingAsyncAtom()`.
///
/// Like `SKAsyncAtomRef` but the task closure can throw; failures surface as
/// `.failure(error)` in the `AsyncPhase<Success, Error>` value.
public final class SKThrowingAsyncAtomRef<Success>: SKThrowingTaskAtom, @unchecked Sendable {

    // MARK: - Storage

    private let _task: @MainActor (SKAtomTransactionContext) async throws -> Success

    // MARK: - Init

    /// Creates a new anonymous throwing async atom with the given async producer.
    ///
    /// - Parameter task: An async throwing closure that performs work. Errors
    ///   are caught and exposed as `.failure(error)`.
    public init(_ task: @escaping @MainActor (SKAtomTransactionContext) async throws -> Success) {
        _task = task
    }

    // MARK: - SKThrowingTaskAtom

    public func task(context: SKAtomTransactionContext) async throws -> Success {
        try await _task(context)
    }

    // MARK: - Hashable / Equatable (reference identity)

    public static func == (lhs: SKThrowingAsyncAtomRef, rhs: SKThrowingAsyncAtomRef) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
