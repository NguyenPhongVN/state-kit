// MARK: - Inline atom factories
//
// These free functions are the primary ergonomic API for creating atoms without
// defining named struct conformances.  They mirror Jotai's `atom()` and
// Recoil's `atom()` / `selector()` — each call allocates a new reference-typed
// atom so that two calls with the same value produce *different*, independent
// atoms in the store.
//
// Always declare the result at module / type scope (static let, top-level let),
// **never** inside a view body — creating a new atom on every render would
// produce a fresh atom on every render.
//
// ```swift
// // ✅ Good — stable identity
// let countAtom   = atom(0)
// let doubleAtom  = selector { ctx in ctx.watch(countAtom) * 2 }
//
// // ❌ Bad — new atom on every render, state is lost between renders
// struct MyView: View {
//     var body: some View {
//         let count = atom(0)   // Don't do this
//         …
//     }
// }
// ```

// MARK: - State atom

/// Creates an inline mutable atom whose initial value is `defaultValue`.
///
/// ```swift
/// let counterAtom = atom(0)
/// let nameAtom    = atom("Alice")
/// ```
///
/// - Parameter defaultValue: The initial value. Evaluated once per store on
///   first access using an `@autoclosure`.
/// - Returns: A new `SKAtomRef<Value>` with a unique identity.
public func atom<Value>(
    _ defaultValue: @escaping @autoclosure @MainActor () -> Value
) -> SKAtomRef<Value> {
    SKAtomRef(defaultValue)
}

// MARK: - Value (derived) atom

/// Creates an inline read-only atom whose value is derived from other atoms.
///
/// Every `context.watch(_:)` call inside `compute` records a reactive
/// dependency.  When any watched atom changes, `compute` is re-evaluated.
///
/// ```swift
/// let countAtom  = atom(0)
/// let doubleAtom = selector { ctx in ctx.watch(countAtom) * 2 }
/// ```
///
/// - Parameter compute: A closure that reads and watches atoms, returning the
///   derived value.
/// - Returns: A new `SKSelectorRef<Value>` with a unique identity.
public func selector<Value>(
    _ compute: @escaping @MainActor (SKAtomTransactionContext) -> Value
) -> SKSelectorRef<Value> {
    SKSelectorRef(compute)
}

// MARK: - Async atom (non-throwing)

/// Creates an inline async atom that produces an `AsyncPhase<Success, Never>`.
///
/// Starts at `.loading`; transitions to `.success(result)` when the task
/// completes.
///
/// ```swift
/// let postsAtom = asyncAtom { _ in
///     await PostService.loadAll()
/// }
/// ```
///
/// - Parameter task: An async closure that performs work and returns the
///   result.
/// - Returns: A new `SKAsyncAtomRef<Success>` with a unique identity.
public func asyncAtom<Success>(
    _ task: @escaping @MainActor (SKAtomTransactionContext) async -> Success
) -> SKAsyncAtomRef<Success> {
    SKAsyncAtomRef(task)
}

// MARK: - Throwing async atom

/// Creates an inline async atom that can throw, producing
/// `AsyncPhase<Success, Error>`.
///
/// Starts at `.loading`; transitions to `.success(result)` or `.failure(error)`.
///
/// ```swift
/// let profileAtom = throwingAsyncAtom { _ in
///     try await API.fetchProfile()
/// }
/// ```
///
/// - Parameter task: An async throwing closure.
/// - Returns: A new `SKThrowingAsyncAtomRef<Success>` with a unique identity.
public func throwingAsyncAtom<Success>(
    _ task: @escaping @MainActor (SKAtomTransactionContext) async throws -> Success
) -> SKThrowingAsyncAtomRef<Success> {
    SKThrowingAsyncAtomRef(task)
}
