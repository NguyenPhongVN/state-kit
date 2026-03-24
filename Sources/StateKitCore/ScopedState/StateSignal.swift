import Observation

/// An `@Observable` reference-type container for a single hook state value.
///
/// `StateSignal` is the reactive backbone of state-driven hooks. Because it
/// is marked `@Observable`, SwiftUI's observation system tracks reads of
/// `value` during a `StateScope` body evaluation. When `value` is later
/// mutated — by a `useState` setter, a `useReducer` dispatch, or a
/// `useAsync` task completion — SwiftUI invalidates the `StateScope` and
/// schedules a re-render.
///
/// ## Contrast with `StateRef`
///
/// `StateRef<T>` is structurally identical but is **not** `@Observable`.
/// Mutating a `StateRef.value` is invisible to SwiftUI and never triggers
/// a re-render. Choose `StateSignal` when state changes should drive the
/// UI; choose `StateRef` for values that must survive renders but should
/// not cause them (timers, cancellables, cached objects).
///
/// ## Usage
///
/// `StateSignal` is an implementation detail of the hook layer. It is
/// allocated inside hook internals (`_useState`, `_HookReducerBox`,
/// `_HookAsyncBox`, etc.) and stored in `StateContext.states`. Callers
/// interact with the value through hook-returned tuples or phase enums
/// rather than holding `StateSignal` directly.
@Observable
public final class StateSignal<T> {

    /// The current state value.
    ///
    /// Reads are tracked by the `@Observable` machinery. Writes notify
    /// SwiftUI, which re-renders the enclosing `StateScope` on the next
    /// run loop cycle.
    public var value: T

    /// Creates a signal with the given initial value.
    ///
    /// - Parameter value: The initial state value for this signal.
    public init(_ value: T) {
        self.value = value
    }
}
