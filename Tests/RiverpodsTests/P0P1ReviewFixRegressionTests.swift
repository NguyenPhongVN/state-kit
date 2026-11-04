import Testing
import Combine
import Foundation
import SwiftUI
@testable import Riverpods

// Regression tests for specs/010-p0-p1-review-fixes (quality review 2026-11-05).
// Each test pins one documented contract that the engine violated at tip 4694ea5.

// MARK: - Helpers

/// Lock-protected single-value recorder for events delivered on the main actor.
final class EventBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value?
    var value: Value? {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
    func set(_ v: Value) {
        lock.lock()
        _value = v
        lock.unlock()
    }
}

/// Counts provider lifecycle events dispatched through `ProviderObserver`.
final class LifecycleCounter: ProviderObserver, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var added = 0
    private(set) var updated = 0
    private(set) var disposed = 0

    func didAddProvider<P: ProviderProtocol>(_ provider: P, value: P.State, container: ProviderContainer) {
        lock.lock()
        added += 1
        lock.unlock()
    }

    func didUpdateProvider<P: ProviderProtocol>(_ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer) {
        lock.lock()
        updated += 1
        lock.unlock()
    }

    func didDisposeProvider<P: ProviderProtocol>(_ provider: P, container: ProviderContainer) {
        lock.lock()
        disposed += 1
        lock.unlock()
    }
}

/// Bounded polling wait (mirrors the repo's weak-reference regression pattern).
/// MainActor-isolated: condition closures read MainActor-confined test state.
@MainActor
func waitFor(_ condition: @escaping () -> Bool, iterations: Int = 200, intervalMs: UInt64 = 5) async -> Bool {
    for _ in 0..<iterations {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: intervalMs * 1_000_000)
    }
    return condition()
}

// MARK: - US1: Override-by-provider (P0 crash)

@MainActor
@Suite("010 — Override by provider")
struct OverrideByProviderRegressionTests {

    @Test("override-by-provider serves the mock without crashing")
    func overrideByProviderServesMock() {
        let real = Provider { _ in "Real" }
        let mock = Provider { _ in "Mock" }
        let container = ProviderContainer(overrides: [real.overrideWithProvider(mock)])

        // At tip this path hit a strict metatype mismatch → fatalError, because
        // every real element is a ProviderElement subclass, never the exact base.
        #expect(container.read(real) == "Mock")
    }

    @Test("override-by-provider works for the FutureProvider kind")
    func overrideByProviderFutureKind() async {
        let real = FutureProvider<Int> { _ in 1 }
        let mock = FutureProvider<Int> { _ in 99 }
        let container = ProviderContainer(overrides: [real.overrideWithProvider(mock)])

        let recorder = EventBox<Int>()
        let sub = container.listen(real, fireImmediately: false) { _, new in
            if case .data(let v) = new { recorder.set(v) }
        }
        _ = container.read(real)
        let sawMock = await waitFor { recorder.value == 99 }
        #expect(sawMock, "override replaces the future implementation; listener must see the mock value")
        sub.close()
    }

    @Test("value-override path keeps its behavior (no regression)")
    func valueOverrideStillWorks() {
        let p = Provider { _ in "Real" }
        let container = ProviderContainer(overrides: [p.overrideWith("Mock")])
        #expect(container.read(p) == "Mock")
    }
}

// MARK: - US2: Listener event correctness

@MainActor
@Suite("010 — Listener events")
struct ListenerEventRegressionTests {

    @Test("listener attached to a fresh provider observes exactly one resume signal")
    func resumeFiresExactlyOnce() async {
        let container = ProviderContainer()
        let resumes = EventBox<Int>()
        let received = EventBox<Int>()

        let p = Provider<Int> { ref in
            ref.onResume { [weak resumesBox = resumes] in
                guard let box = resumesBox else { return }
                box.set((box.value ?? 0) + 1)
            }
            return 7
        }

        let sub = container.listen(p, fireImmediately: true) { _, new in received.set(new) }
        let gotValue = await waitFor { received.value == 7 }
        #expect(gotValue, "fire-immediately listener must receive the initial value")
        #expect(resumes.value == 1, "resume must fire exactly once per subscription (0→1 transition)")
        sub.close()
    }

    @Test("future provider completion reaches container listeners")
    func futureCompletionReachesListeners() async {
        let container = ProviderContainer()
        let fp = FutureProvider<Int> { _ in
            try await Task.sleep(nanoseconds: 20_000_000)
            return 42
        }

        let recorder = EventBox<Int>()
        let sub = container.listen(fp, fireImmediately: false) { _, new in
            if case .data(let v) = new { recorder.set(v) }
        }
        _ = container.read(fp)

        let sawCompletion = await waitFor { recorder.value == 42 }
        #expect(sawCompletion, "listener must receive the future's success completion")
        sub.close()
    }

    @Test("future provider failure reaches container listeners")
    func futureFailureReachesListeners() async {
        struct Boom: Error {}
        let container = ProviderContainer()
        let fp = FutureProvider<Int> { _ in
            try await Task.sleep(nanoseconds: 20_000_000)
            throw Boom()
        }

        let recorder = EventBox<Bool>()
        let sub = container.listen(fp, fireImmediately: false) { _, new in
            if case .error = new { recorder.set(true) }
        }
        _ = container.read(fp)

        let sawFailure = await waitFor { recorder.value == true }
        #expect(sawFailure, "listener must receive the future's failure event")
        sub.close()
    }

    @Test("stream events reach container listeners")
    func streamEventsReachListeners() async {
        let container = ProviderContainer()
        let sp = StreamProvider<Int> { _ in
            Just(1).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        let recorder = EventBox<Int>()
        let sub = container.listen(sp, fireImmediately: false) { _, new in
            if case .data(let v) = new { recorder.set(v) }
        }
        _ = container.read(sp)

        let sawEvent = await waitFor { recorder.value == 1 }
        #expect(sawEvent, "listener must receive streamed values")
        sub.close()
    }
}

// MARK: - US3: Container hierarchy correctness

@MainActor
@Suite("010 — Container hierarchy")
struct HierarchyRegressionTests {

    @Test("listener removal disposes the parent-owned element and releases it")
    func crossContainerDisposeReleasesParentElement() async {
        let parent = ProviderContainer()
        let child = ProviderContainer(parent: parent)

        final class WeakBox: @unchecked Sendable {
            weak var element: AnyObject?
        }
        let box = WeakBox()

        let p = Provider<Int>(autoDispose: true) { _ in 3 }
        // Scope the strong handle so only the owning container's registry keeps
        // the element alive — that's the reference the fix must release.
        do {
            let element = child.ensureElement(for: p) // delegated up: owned by parent
            box.element = element
        }

        _ = child.watch(p)
        child.removeListener(for: p)

        let released = await waitFor { box.element == nil }
        #expect(released, "parent-owned element must be released after child listener removal (no zombie in parent registry)")
    }

    @Test("override scope resolves unoverridden providers from the shared parent")
    func overrideScopeFallsBackToParent() {
        let shared = ProviderContainer.shared
        let p = Provider { _ in "base" }
        let other = Provider { _ in "shared-state" }
        _ = shared.read(other)

        let scoped = ProviderContainer(parent: shared, overrides: [p.overrideWith("Mock")])
        #expect(scoped.read(p) == "Mock", "override applies locally")
        #expect(scoped.read(other) == "shared-state", "unoverridden provider resolves against the parent")
    }

    @Test("ProviderScope(overrides:) wires the shared parent container")
    func providerScopeWiresParent() {
        let p = Provider { _ in "base" }
        let scope = ProviderScope(overrides: [p.overrideWith("Mock")]) {
            EmptyView()
        }
        #expect(scope.container.parent === ProviderContainer.shared,
                "override scope must consult the shared container for unoverridden providers")
    }
}

// MARK: - US4: Keep-alive idempotency

@MainActor
@Suite("010 — Keep-alive")
struct KeepAliveRegressionTests {

    @Test("double-close keeps the provider alive while a second link is open")
    func keepAliveDoubleClose() {
        let container = ProviderContainer()
        let counter = LifecycleCounter()
        container.addObserver(counter)

        final class LinkBox: @unchecked Sendable {
            var links: [KeepAliveLink] = []
        }
        let box = LinkBox()

        let p = Provider<Int>(autoDispose: true) { ref in
            box.links.append(ref.keepAlive())
            box.links.append(ref.keepAlive())
            return 5
        }
        _ = container.read(p) // create runs: two keep-alive claims
        #expect(box.links.count == 2)

        // Double-close of one link must be a no-op (doc: "Safe to call multiple times").
        box.links[0].close()
        box.links[0].close()

        #expect(counter.disposed == 0, "provider must stay alive while the second link is open")

        // Releasing the remaining claim allows disposal.
        box.links[1].close()
        #expect(counter.disposed == 1, "provider must dispose once all keep-alive claims are released")
    }
}
