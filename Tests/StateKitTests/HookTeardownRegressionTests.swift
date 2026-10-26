import Testing
import StateKit
import StateKitTesting
import Combine
import Foundation

// Regression suites for spec 008 US1: hook boxes must not retain their own
// work. Releasing the hook slot (StateTest.reset()) must deallocate the box
// (weak-reference assertion) and cancel the in-flight task/subscription.

/// Suspends well past the test lifetime; cancellation makes it return early.
/// Captures nothing, so the only box retention can come from the hook itself.
private func neverResolvingSleep() async throws -> Int {
    try await Task.sleep(nanoseconds: 60_000_000_000)
    return 0
}

@MainActor
@Suite("Hook Teardown Regression — P1 fixes")
struct HookTeardownRegressionTests {

    @Test("useAsync box deallocates on scope teardown")
    func useAsyncTeardown() {
        let h = StateTest()
        _ = h.render { useAsync { try await neverResolvingSleep() } }
        weak var weakBox = h.context.states[0] as AnyObject?
        #expect(weakBox != nil, "box should exist after first render")

        h.reset()
        #expect(weakBox == nil, "box leaked: the hook's task closure retains the box")
    }

    @Test("useAsyncSequence box deallocates and iteration stops on teardown")
    func useAsyncSequenceTeardown() async throws {
        let h = StateTest()
        let terminated = TerminatedFlag()
        var continuation: AsyncStream<Int>.Continuation?
        let stream = AsyncStream<Int> { cont in
            cont.onTermination = { _ in terminated.mark() }
            continuation = cont
        }

        _ = h.render { useAsyncSequence(updateStrategy: .once, { stream }) }
        weak var weakBox = h.context.states[0] as AnyObject?
        #expect(weakBox != nil)

        h.reset()
        #expect(weakBox == nil, "box leaked: the pump task closure retains the box")

        // The pump must be cancelled: the stream terminates instead of draining.
        continuation?.yield(1)
        for _ in 0..<200 {
            if terminated.isTerminated { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(terminated.isTerminated, "sequence kept being consumed after teardown")
    }

    @Test("usePublisher box deallocates and unsubscribes on teardown")
    func usePublisherTeardown() {
        let h = StateTest()
        let subject = PassthroughSubject<Int, Never>()
        _ = h.render { usePublisher(updateStrategy: nil, { subject.eraseToAnyPublisher() }) }
        weak var weakBox = h.context.states[0] as AnyObject?
        #expect(weakBox != nil)

        h.reset()
        #expect(weakBox == nil, "box leaked: the sink closure retains the box")

        // Post-teardown emissions must not crash; the subscription is cancelled.
        subject.send(1)
        #expect(weakBox == nil)
    }

    @Test("useAsyncPerform box deallocates after in-flight perform on teardown")
    func useAsyncPerformTeardown() async throws {
        let h = StateTest()
        let perform = h.render { useAsyncPerform { try await neverResolvingSleep() } }.perform
        perform()
        weak var weakBox = h.context.states[0] as AnyObject?
        #expect(weakBox != nil)

        h.reset()
        #expect(weakBox == nil, "box leaked: the perform task closure retains the box")
    }

    @Test("useAsyncRefresh box deallocates after in-flight refresh on teardown")
    func useAsyncRefreshTeardown() async throws {
        let h = StateTest()
        let refresh = h.render { useAsyncRefresh { try await neverResolvingSleep() } }.refresh
        refresh()
        weak var weakBox = h.context.states[0] as AnyObject?
        #expect(weakBox != nil)

        h.reset()
        #expect(weakBox == nil, "box leaked: the refresh task closure retains the box")
    }

    @Test("usePublisherPerform box deallocates on teardown")
    func usePublisherPerformTeardown() {
        let h = StateTest()
        let subject = PassthroughSubject<Int, Never>()
        let perform = h.render {
            usePublisherPerform(updateStrategy: nil, { subject.eraseToAnyPublisher() })
        }.perform
        perform()
        weak var weakBox = h.context.states[0] as AnyObject?
        #expect(weakBox != nil)

        h.reset()
        #expect(weakBox == nil, "box leaked: the sink closure retains the box")

        subject.send(1)
        #expect(weakBox == nil)
    }

    @Test("usePublisherRefresh box deallocates on teardown")
    func usePublisherRefreshTeardown() {
        let h = StateTest()
        let subject = PassthroughSubject<Int, Never>()
        let refresh = h.render {
            usePublisherRefresh(updateStrategy: nil, { subject.eraseToAnyPublisher() })
        }.refresh
        refresh()
        weak var weakBox = h.context.states[0] as AnyObject?
        #expect(weakBox != nil)

        h.reset()
        #expect(weakBox == nil, "box leaked: the sink closure retains the box")

        subject.send(1)
        #expect(weakBox == nil)
    }

    @Test("completed work does not keep the box alive after teardown")
    func completedWorkReleasesBox() async throws {
        let h = StateTest()
        _ = h.render { useAsync { 42 } }
        weak var weakBox = h.context.states[0] as AnyObject?

        // Let the task finish before teardown; the box must still deallocate.
        try await Task.sleep(for: .milliseconds(50))
        h.reset()

        for _ in 0..<100 where weakBox != nil {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(weakBox == nil, "box leaked even after its work completed")
    }
}

/// Thread-safe one-shot termination flag shared with `onTermination` callbacks.
final class TerminatedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var terminated = false

    func mark() {
        lock.lock()
        terminated = true
        lock.unlock()
    }

    var isTerminated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminated
    }
}
