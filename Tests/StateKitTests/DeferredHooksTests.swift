import Testing
import Foundation
import StateKit

/// All renders in these tests share one StateContext (one "component") and
/// the suite is serialized on the main actor — the hooks' runtime requires it.
@MainActor
@Suite("Deferred Hooks — Polish Pass", .serialized)
struct DeferredHooksTests {

    private func render(_ context: StateContext, _ body: @MainActor () -> Void) {
        StateRuntime.stateRun(context: context) { body() }
    }

    @Test("useDeferred returns the source immediately on first render")
    func firstRenderImmediate() {
        let context = StateContext()
        var observed: Int?

        render(context) { observed = useDeferred(7) }

        #expect(observed == 7)
    }

    @Test("useDeferred catches up to the latest source after rapid changes")
    func deferredCatchesUp() async {
        let context = StateContext()
        var source = 1

        func renderPass() -> Int {
            var value: Int?
            render(context) { value = useDeferred(source) }
            return value ?? -1
        }

        _ = renderPass() // baseline: deferred = 1

        // Three rapid changes before any catch-up render.
        source = 2
        _ = renderPass()
        source = 3
        _ = renderPass()
        source = 4
        let lagging = renderPass() // still an older deferred copy

        // Let the low-priority catch-up land.
        try? await Task.sleep(nanoseconds: 250_000_000)

        let caughtUp = renderPass()
        #expect(lagging <= 3, "deferred copy lags behind the urgent value")
        #expect(caughtUp == 4, "deferred must coalesce to the latest source (got \(caughtUp))")
    }

    @Test("useTransition isPending is true during awaited work and false after")
    func transitionLifecycle() async {
        final class Gate: @unchecked Sendable {
            private let lock = NSLock()
            private var open = false
            func release() {
                lock.lock(); defer { lock.unlock() }
                open = true
            }
            var isOpen: Bool {
                lock.lock(); defer { lock.unlock() }
                return open
            }
        }

        let context = StateContext()
        let gate = Gate()
        var isPending = false
        var start: (@MainActor @escaping () async -> Void) -> Void = { _ in }

        render(context) { (isPending, start) = useTransition() }
        #expect(isPending == false)

        start {
            while !gate.isOpen {
                await Task.yield()
            }
        }

        // Re-render while the gated work is still in flight.
        render(context) { (isPending, _) = useTransition() }
        #expect(isPending == true, "isPending must be true while the work is in flight")

        gate.release()
        try? await Task.sleep(nanoseconds: 100_000_000)

        render(context) { (isPending, _) = useTransition() }
        #expect(isPending == false, "isPending must clear after the work completes")
    }
}
