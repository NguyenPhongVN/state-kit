import SwiftUI

/// A read-only property wrapper that observes an async atom's `AsyncPhase`.
///
/// `@SKTask` works with both `SKTaskAtom` and `SKThrowingTaskAtom`. The wrapped
/// value is an `AsyncPhase` that starts at `.loading` and transitions to
/// `.success` or `.failure` when the async work completes.
///
/// For synchronous derived atoms, use `@SKValue`. For mutable atoms, use
/// `@SKState`.
///
/// ## Usage with a non-throwing atom
///
/// ```swift
/// struct FeedView: View {
///     @SKTask(FeedAtom()) var phase
///
///     var body: some View {
///         switch phase {
///         case .loading:         ProgressView()
///         case .success(let f):  PostList(posts: f)
///         case .idle, .failure:  EmptyView()
///         }
///     }
/// }
/// ```
///
/// ## Usage with a throwing atom
///
/// ```swift
/// @SKTask(ProfileAtom(id: "abc")) var phase   // AsyncPhase<Profile, Error>
/// ```
///
/// ## Refresh
///
/// Use the projected value to obtain a `SKAtomViewContext` and call `refresh`:
///
/// ```swift
/// @SKTask(feedAtom) var feedPhase
///
/// Button("Retry") {
///     Task { await context.refresh(feedAtom) }
/// }
/// ```
@MainActor
@propertyWrapper
public struct SKTask<A: SKAsyncPhaseAtom>: DynamicProperty {

    // MARK: - Dependencies

    @Environment(\.skAtomStore) private var store
    private let atom: A

    // MARK: - Init

    /// Creates an async-phase observer for `atom`.
    ///
    /// - Parameter atom: A `SKTaskAtom` or `SKThrowingTaskAtom` to observe.
    public init(_ atom: A) {
        self.atom = atom
    }

    // MARK: - DynamicProperty

    /// The atom's current `AsyncPhase`.
    ///
    /// Starts as `.loading` on first access, then transitions to `.success` or
    /// `.failure` once the underlying async task completes.
    public var wrappedValue: A.Value {
        atom._getOrCreateBox(in: store).value
    }
}
