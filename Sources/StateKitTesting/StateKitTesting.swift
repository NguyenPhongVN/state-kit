import Foundation
import StateKit

/// A lightweight test harness for running HookKit hooks without SwiftUI.
///
/// `HookTest` owns a single `HookContext` and provides a `render` function that:
/// - resets the hook index,
/// - sets up `HookRuntime.current`,
/// - runs your hook code,
/// - then tears down the runtime.
///
/// Because the same `HookContext` is reused, state stored by hooks persists
/// across `render` calls, mirroring how hooks behave across SwiftUI re-renders.
///
/// ### Example
/// ```swift
/// import Testing
/// import HookKit
/// import HookKitTesting
///
/// @Test @MainActor
/// func useState_persistsAcrossRenders() {
///     let test = StateTest()
///
///     let first = test.render {
///         useState(0).value
///     }
///     #expect(first == 0)
///
///     _ = test.render {
///         let count = useState(0)
///         count.value += 1
///         return count.value
///     }
///
///     let third = test.render {
///         useState(0).value
///     }
///     #expect(third == 1)
/// }
/// ```
@MainActor
public final class StateTest {
    /// The underlying hook context reused across renders.
    public let context: StateContext

    /// Number of times `render` has been called.
    public private(set) var renderCount: Int = 0

    public init(context: StateContext = StateContext()) {
        self.context = context
    }

    /// Runs a single render pass using this test's `HookContext`.
    ///
    /// - Parameter body: Hook code to execute while `HookRuntime.current` is set.
    /// - Returns: Whatever `body` returns.
    @discardableResult
    public func render<T>(_ body: () -> T) -> T {
        renderCount += 1
        StateRuntime.begin(context)
        let result = body()
        StateRuntime.end()
        return result
    }

    /// Runs a render pass and returns the full `HookContext` state storage afterwards.
    ///
    /// This is useful for white-box tests that need to inspect internal state ordering.
    public func renderAndCaptureStates<T>(_ body: () -> T) -> (result: T, states: [Any]) {
        let result = render(body)
        return (result, context.states)
    }

    /// Clears all stored hook states and resets the render counter.
    public func reset() {
        context.states.removeAll(keepingCapacity: false)
        context.reset()
        renderCount = 0
    }
}
