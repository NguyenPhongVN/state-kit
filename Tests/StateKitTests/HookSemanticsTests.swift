import Testing
import StateKit
import StateKitTesting
import Foundation

// Spec 009 US3: hook semantics — overlap-safe transition pending, external
// cancellation surfacing, and deterministic reducer re-entrancy.

@MainActor
@Suite("Hook Semantics — 009 US3")
struct HookSemanticsTests {

    @Test("useTransition keeps isPending until the last overlapping start finishes")
    func transitionOverlapPending() async throws {
        let h = StateTest()

        struct Transition {
            let isPending: Bool
            let start: @MainActor () async -> Void
        }
        let transition = h.render {
            useTransition()
        }

        #expect(transition.isPending == false)

        // Start two overlapping transitions; release the first quickly.
        let firstDone = ReleasedFlag()
        let secondDone = ReleasedFlag()
        transition.start {
            try? await Task.sleep(for: .milliseconds(30))
            firstDone.mark()
        }
        _ = h.render { useTransition() }  // observe isPending == true
        #expect(h.render { useTransition().isPending } == true)

        transition.start {
            try? await Task.sleep(for: .milliseconds(120))
            secondDone.mark()
        }

        // After the first finishes, the second is still in flight → pending.
        try await Task.sleep(for: .milliseconds(80))
        #expect(firstDone.isDone)
        #expect(h.render { useTransition().isPending } == true,
                "isPending dropped early while an overlapping transition still ran")

        try await Task.sleep(for: .milliseconds(120))
        #expect(secondDone.isDone)
        #expect(h.render { useTransition().isPending } == false)
    }

    @Test("external cancellation surfaces as failure instead of stuck loading")
    func externalCancellationSurfaces() async throws {
        let h = StateTest()
        let perform = h.render {
            useAsyncPerform { () -> Int in
                try await Task.sleep(for: .seconds(60))
                return 1
            }
        }.perform
        perform()
        try await Task.sleep(for: .milliseconds(20))

        let phase = h.render {
            useAsyncPerform { () -> Int in
                try await Task.sleep(for: .seconds(60))
                return 1
            }
        }.phase
        #expect(phase.isLoading)

        // Simulate an externally-caused cancellation: throw CancellationError
        // from an operation while the hook task itself is NOT cancelled.
        let h2 = StateTest()
        _ = h2.render {
            useAsyncPerform { () -> Int in
                throw CancellationError()
            }
        }.perform()
        try await Task.sleep(for: .milliseconds(20))

        let phase2 = h2.render {
            useAsyncPerform { () -> Int in
                throw CancellationError()
            }
        }.phase
        #expect(phase2.isFailure,
                "un-caused CancellationError left the phase stuck at .loading")
    }

    @Test("reducer tolerates re-entrant dispatch deterministically")
    func reducerReentrancy() {
        let h = StateTest()

        enum Action { case add(Int), addThenChain(Int) }
        // Chain: a reducer action that dispatches again. The inner action must
        // apply after the outer one (queued), not crash on exclusivity.
        final class Chain: @unchecked Sendable {
            var dispatch: ((Action) -> Void)?
        }
        let chain = Chain()
        let (value2, dispatch2) = h.render {
            useReducer(0) { (state: inout Int, action: Action) in
                switch action {
                case .add(let n):
                    state += n
                case .addThenChain(let n):
                    state += n
                    chain.dispatch?(.add(100))
                }
            }
        }
        _ = value2
        chain.dispatch = dispatch2
        dispatch2(.addThenChain(1))

        let final = h.render {
            useReducer(0) { (state: inout Int, action: Action) in
                switch action {
                case .add(let n): state += n
                case .addThenChain(let n): state += n; chain.dispatch?(.add(100))
                }
            }
        }
        #expect(final.0 == 101, "queued inner action was lost or applied out of order")
    }
}

final class ReleasedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func mark() { lock.lock(); done = true; lock.unlock() }
    var isDone: Bool { lock.lock(); defer { lock.unlock() }; return done }
}
