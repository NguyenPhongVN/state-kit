/// A plain reference-type container for a single hook value that persists
/// across renders without triggering re-renders when mutated.
///
/// `StateRef` is the non-reactive counterpart to `StateSignal`. Both are
/// `final class` types stored in `StateContext.states`, but unlike
/// `StateSignal`, `StateRef` is **not** `@Observable`. SwiftUI's observation
/// system never tracks reads or writes of `value`, so mutating it has no
/// effect on the render cycle.
///
/// ## When to use `StateRef` vs `StateSignal`
///
/// | | `StateSignal` | `StateRef` |
/// |---|---|---|
/// | Survives re-renders | yes | yes |
/// | Mutation triggers re-render | yes | no |
/// | Used by | `useState`, `useReducer`, async hooks | `useRef` |
///
/// Use `StateRef` for values that must outlive individual renders but whose
/// changes should not drive the UI — for example: active `Timer` instances,
/// `AnyCancellable` tokens, scroll position caches, or counters used only
/// inside event callbacks.
///
/// ## Usage
///
/// `StateRef` is allocated by `useRef(_:)` and stored in
/// `StateContext.states`. Callers receive the `StateRef` object directly
/// from `useRef` and read or write `value` freely without triggering
/// SwiftUI observation.
public final class StateRef<T> {

    /// The current stored value.
    ///
    /// Reads and writes are not tracked by SwiftUI's observation system.
    /// Mutating this property does not schedule a re-render.
    public var value: T

    /// Creates a ref with the given initial value.
    ///
    /// - Parameter value: The initial value for this ref slot.
    public init(_ value: T) {
        self.value = value
    }
}
