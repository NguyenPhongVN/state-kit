import Testing
import Combine
import Foundation
import StateKitAtoms
@testable import Riverpods

// Spec 008 US5: Future/Stream/AsyncSequence provider elements must not retain
// themselves through their onDispose registrations or work closures.
//
// Verification contract (revised during implementation): the element's
// lifecycle exit is the transition-based disposal path — listener count
// reaching zero triggers checkAutoDispose, which disposes the element and
// removes it from the container's element map. Each suite drives that real
// lifecycle (addListener → work completes → removeListener → container
// released) and asserts the element deallocates and its work is cancelled.
//
// Known residual cycle (out of scope, deferred to feature 009): the element's
// strong `container` back-reference (element → container → elements dict →
// element) pins both objects when an element is abandoned without a
// listener-driven disposal; see spec.md Assumptions.

@MainActor
@Suite("Provider Element Deallocation — P1 fixes")
struct ProviderElementDeallocationTests {

    @Test("FutureProviderElement deallocates through listener-driven disposal")
    func futureElementDeallocates() async throws {
        var container: ProviderContainer? = ProviderContainer()
        let provider = FutureProvider { _ -> Int in
            try await Task.sleep(nanoseconds: 20_000_000)
            return 42
        }
        _ = container!.addListener(for: provider)  // creates element, starts fetch
        weak var weakElement: AnyObject? = container!.ensureElement(for: provider)
        #expect(weakElement != nil)

        // Let the fetch finish so only lifecycle edges remain.
        try await Task.sleep(for: .milliseconds(200))

        container!.removeListener(for: provider)  // transition disposal + map removal
        container = nil

        for _ in 0..<200 where weakElement != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(weakElement == nil,
                "element leaked: the listener-driven disposal path did not release it")
    }

    @Test("StreamProviderElement deallocates through listener-driven disposal")
    func streamElementDeallocates() async throws {
        var container: ProviderContainer? = ProviderContainer()
        let subject = PassthroughSubject<Int, Error>()
        let provider = StreamProvider { _ -> AnyPublisher<Int, Error> in
            subject.eraseToAnyPublisher()
        }
        _ = container!.addListener(for: provider)
        weak var weakElement: AnyObject? = container!.ensureElement(for: provider)
        #expect(weakElement != nil)

        try await Task.sleep(for: .milliseconds(100))

        container!.removeListener(for: provider)
        container = nil

        for _ in 0..<200 where weakElement != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(weakElement == nil,
                "element leaked: the listener-driven disposal path did not release it")

        // Post-dispose emissions must not crash or resurrect anything.
        subject.send(1)
        #expect(weakElement == nil)
    }

    @Test("AsyncSequenceProviderElement deallocates and its pump terminates")
    func sequenceElementDeallocates() async throws {
        var container: ProviderContainer? = ProviderContainer()
        let terminated = TerminatedFlag()
        var continuation: AsyncStream<Int>.Continuation?
        let stream = AsyncStream<Int> { cont in
            cont.onTermination = { _ in terminated.mark() }
            continuation = cont
        }
        let provider = AsyncSequenceProvider { _ -> AsyncStream<Int> in
            stream
        }
        _ = container!.addListener(for: provider)
        weak var weakElement: AnyObject? = container!.ensureElement(for: provider)
        #expect(weakElement != nil)

        try await Task.sleep(for: .milliseconds(100))

        container!.removeListener(for: provider)
        container = nil

        for _ in 0..<200 where weakElement != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(weakElement == nil,
                "element leaked: the listener-driven disposal path did not release it")

        // The pump must be cancelled, not left draining the stream.
        for _ in 0..<100 where !terminated.isTerminated {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(terminated.isTerminated, "pump kept iterating after disposal")
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
