/// The global coordinator for hook execution within a render pass.
///
/// `StateRuntime` is a `@MainActor` namespace (a caseless `enum`) that acts
/// as a thread-confined "current context" register. It provides the
/// mechanism by which hook functions (`useState`, `useRef`, `useMemo`, etc.)
/// discover which `StateContext` to read from and write to during a render.
///
/// ## Render lifecycle
///
/// `StateScope` drives the lifecycle by calling `stateRun(context:body:)` from
/// its `body`:
///
/// 1. `begin(_:)` — resets the context's index to `0` and assigns it to
///    `StateRuntime.current`.
/// 2. `body()` — the `@ViewBuilder` closure executes. Every hook inside it
///    reads `StateRuntime.current` to find the active context and calls
///    `context.nextIndex()` to claim its slot.
/// 3. `end()` — sets `StateRuntime.current` to `nil`, closing the render
///    window. Any hook called after this point will `fatalError`.
///
/// Because all operations are `@MainActor`, there is no concurrent access
/// to `current`; a single render runs to completion before the next begins.
@MainActor
public enum StateRuntime {

    /// The `StateContext` active for the current render pass, or `nil` when
    /// no render is in progress.
    ///
    /// Hooks read this property to find their context. A `nil` value means
    /// the hook was called outside a `StateScope`, which is a programming
    /// error that hooks surface via `fatalError`.
    public static var current: StateContext?

    /// Begins a render pass for `context`.
    ///
    /// Resets the context's slot index to `0` via `context.reset()`, then
    /// assigns it to `current` so that hooks called during the subsequent
    /// `body()` invocation can find it.
    ///
    /// - Parameter context: The `StateContext` owned by the `StateScope`
    ///   that is about to render.
    public static func begin(_ context: StateContext) {
        context.reset()
        current = context
    }

    /// Returns the active `StateContext`, or a fresh one if `current` is `nil`.
    ///
    /// Used internally where a non-optional context is required. Prefer
    /// reading `current` directly in hook implementations so that a missing
    /// context can be surfaced as a `fatalError` with a clear message.
    public static var context: StateContext {
        guardFunction(StateRuntime.current) {
            StateContext()
        }
    }

    /// Ends the current render pass by setting `current` to `nil`.
    ///
    /// Called by `stateRun(context:body:)` after `body()` returns. Any hook
    /// invoked after `end()` will find `StateRuntime.current == nil` and
    /// `fatalError`.
    public static func end() {
        current = nil
    }

    /// Executes `body` within a render pass scoped to `context`.
    ///
    /// Calls `begin(_:)`, invokes `body()`, then calls `end()`, ensuring the
    /// context window is always closed even if `body` returns early. The
    /// return value of `body` is forwarded to the caller — typically the
    /// SwiftUI `View` tree produced by a `StateScope`.
    ///
    /// - Parameters:
    ///   - context: The `StateContext` to activate for this render pass.
    ///   - environment: An optional opaque environment value (e.g.
    ///     `EnvironmentValues`) injected by `StateScope`. Stored in
    ///     `context.injectedEnvironment` so that `useEnvironment(_:)` and
    ///     atom hooks can retrieve the correct environment without SwiftUI
    ///     property-wrapper access. Pass `nil` (the default) to leave any
    ///     previously stored environment unchanged.
    ///   - body: The closure to execute while `current` is set. For
    ///     `StateScope` this is the user's `@ViewBuilder` content closure.
    /// - Returns: The value returned by `body`.
    @MainActor
    public static func stateRun<T>(
        context: StateContext,
        environment: Any? = nil,
        body: @MainActor () -> T
    ) -> T {
        if let environment { context.injectedEnvironment = environment }
        StateRuntime.begin(context)
        let view = body()
        StateRuntime.end()
        return view
    }
}
