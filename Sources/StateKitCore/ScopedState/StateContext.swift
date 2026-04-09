/// The per-`StateScope` store that holds every hook slot for one render tree.
///
/// A single `StateContext` is created by `StateScope` as a `@State` property,
/// meaning SwiftUI owns its lifetime for as long as the view is on screen.
///
/// ## Render cycle
///
/// Before each render `StateRuntime.begin(_:)` calls `reset()` to bring
/// `index` back to `0`. As the `@ViewBuilder` body executes, each hook
/// (`useState`, `useRef`, `useMemo`, etc.) calls `nextIndex()` to claim
/// the next slot in `states`. After the body returns `StateRuntime.end()`
/// clears `StateRuntime.current`.
///
/// Hook identity is **positional**: the nth call to `nextIndex()` always
/// maps to `states[n]`. Hooks must therefore be called in the same order
/// on every render — never inside conditionals or loops.
///
/// ## Properties
///
/// - `states`: The flat array of hook slot objects (`StateSignal`, `StateRef`,
///   `_HookMemoBox`, `_HookAsyncBox`, etc.). Slots are appended on first
///   render and reused on subsequent renders.
/// - `context`: Reserved storage for context-style values (e.g. injected
///   `EnvironmentValues`). Not consumed by `nextIndex()`.
/// - `index`: The next slot position to hand out. Reset to `0` before every
///   render; incremented by each `nextIndex()` call.
public final class StateContext {

    /// Flat array of hook slot objects, indexed by hook call order.
    public var states: [Any] = []

    /// Reserved storage for context-style values such as `EnvironmentValues`.
    /// Not indexed by `nextIndex()`; accessed by scanning the array directly.
    public var context: [Any] = []

    /// The environment value (typically `EnvironmentValues`) injected by the
    /// enclosing `StateScope` before each render. Atom hooks and
    /// `useEnvironment(_:)` read this to pick up the correct store and other
    /// environment values without requiring SwiftUI property-wrapper access.
    ///
    /// Set by `StateRuntime.stateRun(context:environment:body:)`. `nil` means
    /// no environment has been injected yet (e.g. the context was created
    /// outside of a `StateScope`).
    public var injectedEnvironment: Any?

    /// The next hook slot position to hand out. Incremented by `nextIndex()`
    /// and reset to `0` by `reset()` before each render.
    public private(set) var index: Int = 0

    /// Creates a new context, optionally pre-populated with existing hook
    /// slots and a starting index.
    ///
    /// In normal usage `StateScope` creates an empty context via
    /// `StateContext()` and lets the first render populate `states`.
    ///
    /// - Parameters:
    ///   - states: Pre-existing hook slot objects. Defaults to `[]`.
    ///   - index: Starting index. Defaults to `0`.
    public init(states: [Any] = [], index: Int = 0) {
        self.states = states
        self.index = index
    }

    /// Returns the current hook slot index, then increments it.
    ///
    /// Called by every hook at the start of its execution to claim the
    /// next position in `states`. The `defer` ensures the increment
    /// happens after the current value is returned, so the returned index
    /// is always the one the hook should read or write.
    public func nextIndex() -> Int {
        defer { index += 1 }
        return index
    }

    /// Resets `index` to `0`.
    ///
    /// Called by `StateRuntime.begin(_:)` before each render so that the
    /// first hook call on this render claims slot `0`, the second claims
    /// slot `1`, and so on — matching the order from the previous render.
    public func reset() {
        index = 0
    }
}
