import SwiftUI
import StateKitCore

// MARK: - StateTest

/// A synchronous test harness for hook-based render logic.
///
/// `StateTest` manages a `StateContext` and `StateRuntime` lifecycle that
/// mirrors what `StateScope` does during normal SwiftUI rendering, letting
/// you test hook functions (`useState`, `useMemo`, `useReducer`, `useAsync`,
/// `useAtomState`, etc.) directly in unit tests without a running SwiftUI view.
///
/// ## Basic usage
///
/// ```swift
/// let h = StateTest()
///
/// // First render — useState initialises to 0
/// let (v1, set) = h.render { useState(0) }
/// assert(v1 == 0)
///
/// // Mutate state via the setter
/// set(42)
///
/// // Re-render — useState returns the updated value
/// let (v2, _) = h.render { useState(0) }
/// assert(v2 == 42)
/// ```
///
/// ## Testing hooks that use the environment
///
/// Pass an `EnvironmentValues` to `render(environment:_:)` when the hooks
/// inside call `useEnvironment(_:)`. This covers all atom hooks from
/// `StateKitAtoms` (`useAtomState`, `useAtomValue`, `useAtomBinding`, etc.)
/// because they read `\.skAtomStore` from the environment.
///
/// ```swift
/// // Set up an atom store and inject it via environment
/// var env = EnvironmentValues()
/// env.skAtomStore = myStore
///
/// let h = StateTest()
/// let (count, setCount) = h.render(environment: env) {
///     useAtomState(CounterAtom())
/// }
/// ```
///
/// ## Testing async hooks
///
/// `useAsync` starts a `Task` and immediately returns `.loading`. Await the
/// task's completion between renders by suspending in the test function:
///
/// ```swift
/// let h = StateTest()
///
/// let phase1 = h.render { useAsync(updateStrategy: .once) { "done" } }
/// assert(phase1.isLoading)
///
/// await Task.yield()          // let the task finish on the main actor
///
/// let phase2 = h.render { useAsync(updateStrategy: .once) { "done" } }
/// assert(phase2.successValue == "done")
/// ```
///
/// ## Hook ordering
///
/// Hook slots accumulate across calls to `render` exactly as they do in a
/// living `StateScope`. Always call hooks in the same order. Call `reset()`
/// to simulate the view unmounting (releasing all slots).
@MainActor
public final class StateTest {

    // MARK: - State

    /// The `StateContext` shared across all `render` calls.
    ///
    /// Hook slots accumulate here just as they would in a `StateScope`. Their
    /// lifecycle (e.g. `useEffect` cleanup) is tied to the lifetime of this
    /// context.
    public private(set) var context = StateContext()

    /// Number of completed `render` calls on this harness.
    public private(set) var renderCount = 0

    // MARK: - Init

    public init() {}

    // MARK: - Render

    /// Executes `body` in one render pass and returns its value.
    ///
    /// Sets `StateRuntime.current` to `context` for the duration of `body`,
    /// then clears it. Hook slots claimed during `body` persist for the next
    /// call.
    ///
    /// - Parameter body: A closure that calls hook functions and returns a
    ///   value (typically a tuple of state values and setters).
    /// - Returns: Whatever `body` returns.
    @discardableResult
    public func render<T>(_ body: @MainActor () -> T) -> T {
        renderCount += 1
        return StateRuntime.stateRun(context: context, body: body)
    }

    /// Executes `body` in one render pass with a specific SwiftUI environment.
    ///
    /// Injects `environment` into `context.injectedEnvironment` so that hooks
    /// calling `useEnvironment(_:)` — including all `StateKitAtoms` atom hooks
    /// — receive the correct values from the injected environment.
    ///
    /// - Parameters:
    ///   - environment: The `EnvironmentValues` snapshot to inject.
    ///   - body: A closure that calls hook functions and returns a value.
    /// - Returns: Whatever `body` returns.
    @discardableResult
    public func render<T>(environment: EnvironmentValues, _ body: @MainActor () -> T) -> T {
        renderCount += 1
        return StateRuntime.stateRun(context: context, environment: environment, body: body)
    }

    // MARK: - Reset

    /// Releases all hook state and resets the render counter.
    ///
    /// Equivalent to the view being removed from the SwiftUI hierarchy:
    /// every hook slot's `deinit` runs (triggering `useEffect` cleanup
    /// closures), and the next `render` starts from slot 0 with fresh state.
    public func reset() {
        context = StateContext()
        renderCount = 0
    }
}
