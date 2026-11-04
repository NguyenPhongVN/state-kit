import Testing
import Combine
import Foundation
@testable import Riverpods

// Regression tests for specs/011-p2-hardening-ci (named identity, bounded
// propagation, stream ordering). Helpers (EventBox, waitFor, LifecycleCounter)
// are shared with P0P1ReviewFixRegressionTests in this target.

// MARK: - US1: Named provider identity

@MainActor
@Suite("011 — Named provider identity")
struct NamedIdentityRegressionTests {

    final class ComputeCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        func hit() -> Int {
            lock.lock()
            n += 1
            lock.unlock()
            return n
        }
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return n
        }
    }

    @Test("two same-named instances share one element")
    func sameNamedInstancesShareElement() {
        let container = ProviderContainer()
        let counter = ComputeCounter()

        // Recreating a named provider inline (view body pattern) must resolve to
        // the same logical provider — previously each instance leaked an element.
        let first = Provider(name: "inline-counter") { _ in counter.hit() }
        let second = Provider(name: "inline-counter") { _ in counter.hit() }

        #expect(container.read(first) == 1)
        #expect(container.read(second) == 1)
        #expect(counter.count == 1, "same name + same value type must resolve to one element (computed \(counter.count) times)")
    }

    @Test("distinct names stay distinct")
    func distinctNamesStayDistinct() {
        let container = ProviderContainer()
        let counter = ComputeCounter()

        let first = Provider(name: "a") { _ in counter.hit() }
        let second = Provider(name: "b") { _ in counter.hit() }

        #expect(container.read(first) == 1)
        #expect(container.read(second) == 2)
        #expect(counter.count == 2, "distinct names must be distinct elements")
    }

    @Test("same name across different value types stays distinct")
    func sameNameDifferentTypeDistinct() {
        let container = ProviderContainer()
        let counter = ComputeCounter()

        let ints = Provider(name: "shared-key") { _ in counter.hit() }
        let strings = Provider(name: "shared-key") { _ in "s\(counter.hit())" }

        #expect(container.read(ints) == 1)
        #expect(container.read(strings) == "s2")
        #expect(counter.count == 2, "same name with different value types must not collide")
    }

    @Test("unnamed providers keep per-instance identity")
    func unnamedKeepsPerInstanceIdentity() {
        let container = ProviderContainer()
        let counter = ComputeCounter()

        let first = Provider { _ in counter.hit() }
        let second = Provider { _ in counter.hit() }

        #expect(container.read(first) == 1)
        #expect(container.read(second) == 2)
        #expect(counter.count == 2, "unnamed providers keep current per-instance identity (documented limitation)")
    }
}

// MARK: - US4: Stream ordering

@MainActor
@Suite("011 — Stream ordering")
struct StreamOrderRegressionTests {

    @Test("rapid burst preserves emission order in observed state")
    func streamBurstPreservesOrder() async {
        let container = ProviderContainer()
        let subject = PassthroughSubject<Int, Error>()
        let sp = StreamProvider<Int> { _ in subject.eraseToAnyPublisher() }

        let recorded = EventBox<[Int]>()
        let sub = container.listen(sp, fireImmediately: false) { _, new in
            guard case .data(let v) = new else { return }
            let current = recorded.value ?? []
            recorded.set(current + [v])
        }
        _ = container.read(sp) // subscribe

        let emitQueue = DispatchQueue(label: "011-stream-emit")
        emitQueue.async {
            for value in [1, 2, 3, 4, 5] {
                subject.send(value)
            }
        }

        let done = await waitFor { (recorded.value ?? []).count == 5 }
        #expect(done, "all five values must reach the listener")
        #expect(recorded.value == [1, 2, 3, 4, 5], "state transitions must follow emission order, got \(recorded.value ?? [])")
        sub.close()
    }
}
