import Testing
import Foundation
import StateKit
@testable import Riverpods

// Spec 009 US2: Riverpods semantic contracts — parent removeListener,
// conditional-watch edge rebuild, stale-future throw, AsyncNotifier dispose.

@MainActor
@Suite("Riverpods Semantics — 009 US2")
struct RiverpodsSemanticsTests {

    // MARK: T003 — removeListener resolves parent-served elements

    @Test("removeListener reaches elements served by a parent container")
    func removeListenerReachesParent() {
        let parent = ProviderContainer()
        let child = ProviderContainer(parent: parent)
        let provider = StateProvider { _ in "v" }

        // watch through the child — the element lives in the parent.
        _ = child.watch(provider)
        let element = parent.ensureElement(for: provider)
        #expect(element.listenersCount == 1, "listener count should live on the parent element")

        child.removeListener(for: provider)
        #expect(element.listenersCount == 0,
                "removeListener never reached the parent-served element (leaked listener count)")
    }

    // MARK: T004 — conditional watch edges rebuild per recompute

    @Test("conditional watch drops the stale edge after the branch flips")
    func conditionalWatchRebuildsEdges() {
        let container = ProviderContainer()
        let flag = StateProvider { _ in true }
        let a = StateProvider(name: "branch-a") { _ in "A" }
        let b = StateProvider(name: "branch-b") { _ in "B" }

        var buildCount = 0
        let selector = Provider { ref -> String in
            buildCount += 1
            let useA = ref.watch(flag)
            return ref.watch(useA ? a : b)
        }
        _ = container.read(selector)
        #expect(buildCount == 1)

        let aElement = container.ensureElement(for: a)
        let bElement = container.ensureElement(for: b)
        let selectorID = ProviderID(selector)
        #expect(aElement.dependents.contains(selectorID))
        #expect(!bElement.dependents.contains(selectorID))

        // Flip the branch; the selector recomputes and re-registers edges.
        container.read(flag.notifier).state = false
        #expect(buildCount == 2)
        #expect(container.read(selector) == "B")

        // The stale A edge must be gone: A no longer invalidates the selector…
        let buildsBefore = buildCount
        container.read(a.notifier).state = "A2"
        #expect(buildCount == buildsBefore, "stale edge recomputed the selector on an unrelated change")

        // …and B drives it.
        container.read(b.notifier).state = "B2"
        #expect(buildCount == buildsBefore + 1, "live edge did not invalidate the selector")
    }

    // MARK: T005 — FutureProvider.future throws after a failed refresh

    @Test("future throws the refresh error instead of returning stale data")
    func futureThrowsAfterFailedRefresh() async throws {
        let container = ProviderContainer()
        final class Flaky: Error {}

        var shouldFail = false
        let provider = FutureProvider { _ -> Int in
            if shouldFail { throw Flaky() }
            return 42
        }
        let element = container.ensureElement(for: provider) as! FutureProviderElement<Int>
        _ = element.getState()

        let first = try await element.getFuture()
        #expect(first == 42)

        shouldFail = true
        element.recompute()
        // The refresh runs in a task; wait for it to land the error state.
        for _ in 0..<200 {
            if case .error = element.getState() { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try await #expect(throws: Flaky.self) {
            _ = try await element.getFuture()
        }
    }

    // MARK: T006 — AsyncNotifier dispose cancels work and resumes futures

    @Test("asyncNotifier dispose cancels the build and resumes pending futures")
    func asyncNotifierDisposeCancels() async throws {
        let container = ProviderContainer()
        let provider = AsyncNotifierProvider { SlowAsyncNotifier() }
        let element = container.ensureElement(for: provider)
        _ = container.read(provider)
        try await Task.sleep(for: .milliseconds(30))

        let notifier = container.read(provider.notifier)
        let waiter = Task { try await notifier.future }

        try await Task.sleep(for: .milliseconds(30))
        element.dispose()

        var threw = false
        do {
            _ = try await waiter.value
        } catch is CancellationError {
            threw = true
        } catch {}
        #expect(threw, "dispose left a pending future suspended (or resolved it wrongly)")
    }
}

/// Async notifier whose build suspends until released.
final class SlowAsyncNotifier: AsyncNotifier<Int> {
    static var gate = false

    override init() {
        super.init()
        state = .loading()
    }

    override func build() async throws -> Int {
        while !SlowAsyncNotifier.gate {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(10))
        }
        return 1
    }
}
