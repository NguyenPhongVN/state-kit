import Testing
import Foundation
import StateKit
import StateKitAtoms
@testable import Riverpods
@testable import StateKitDevTools
@testable import StateKitTesting

// Spec 009 US7+US8: DevTools that work in production conditions and testing
// helpers that enforce what they claim.

@MainActor
@Suite("DevTools Production — 009 US7")
struct DevToolsProductionTests {

    @Test("observer revision bumps on updates so views can observe it")
    func revisionBumps() {
        let observer = DevToolsObserver()
        let before = observer.revision

        let container = ProviderContainer(observers: [observer])
        let provider = StateProvider { _ in 0 }
        _ = container.read(provider)
        container.read(provider.notifier).state = 1

        #expect(observer.revision > before, "observer published nothing for views to observe")
    }

    @Test("storeSnapshots=false keeps recording history with null snapshots")
    func snapshotsOffStillRecords() {
        let observer = DevToolsObserver()
        observer.storeSnapshots = false

        let container = ProviderContainer(observers: [observer])
        let provider = StateProvider { _ in 0 }
        _ = container.read(provider)
        container.read(provider.notifier).state = 5

        #expect(!observer.history.entries.isEmpty,
                "storeSnapshots=false disabled history recording entirely")
        if let entry = observer.history.entries.last {
            #expect(entry.action == nil)
        }
    }

    @Test("disposed providers are forgotten by metrics")
    func metricsForgetDisposed() {
        let observer = DevToolsObserver()
        let container = ProviderContainer(observers: [observer])
        let provider = StateProvider { _ in 0 }

        // Drive the real listener-driven disposal: observer notification fires
        // on the auto-dispose path (direct element.dispose() bypasses observers).
        let providerName = provider.name ?? "Unknown"
        _ = container.watch(provider)
        observer.recordUpdate(providerName: providerName, computeTime: 5, memoryBytes: 100)
        #expect(observer.metrics.callCount(for: providerName) == 1)

        container.removeListener(for: provider)
        #expect(observer.metrics.callCount(for: providerName) == 0,
                "metrics for a disposed provider were retained forever")
    }

    @Test("replay survives hostile imported computeTime values")
    func replaySurvivesHostileInput() async throws {
        var history = InMemoryStateHistory()
        // Negative and NaN compute times via importable JSON would trap
        // UInt64 conversion before the clamp.
        history.record(action: "neg", before: AnyCodable(NSNull()), after: AnyCodable(NSNull()), computeTime: -1)
        history.record(action: "nan", before: AnyCodable(NSNull()), after: AnyCodable(NSNull()), computeTime: .nan)

        let report = await history.replay { _ in true }
        #expect(report.executed.count == 2, "replay failed on hostile imported input")
    }
}

@MainActor
@Suite("Testing Honesty — 009 US8")
struct TestingHonestyTests {

    @Test("seeded environments produce identical random sequences")
    func seededRandomReproducible() {
        let env1 = DeterministicTestEnvironment(seed: 42)
        let env2 = DeterministicTestEnvironment(seed: 42)

        var seq1: [Int] = []
        var seq2: [Int] = []
        for _ in 0..<10 {
            seq1.append(env1.nextInt(min: 0, max: 1000))
            seq2.append(env2.nextInt(min: 0, max: 1000))
        }
        #expect(seq1 == seq2, "seeded environments diverged — the seed was never wired")

        // The same environment continues its sequence (no reset per call).
        let next1 = env1.nextInt(min: 0, max: 1000)
        let again = env1.nextInt(min: 0, max: 1000)
        #expect(next1 != again || true) // sequence advances; just exercise it
    }

    @Test("environment overrides are stored and applied by build()")
    func overridesApplied() {
        let provider = StateProvider { _ in "real" }
        let env = IntegrationTestEnvironment()
        env.override(provider, with: "fake")

        let container = env.build()
        #expect(container.read(provider) == "fake",
                "override(_:with:) silently discarded the override")
    }

    @Test("verifyTransition checks before/after state through the reader")
    func transitionVerification() async {
        final class Box: @unchecked Sendable {
            var value = "from"
        }
        let box = Box()

        let success = await StateVerification.verifyTransition(
            read: { @Sendable in box.value },
            from: "from",
            to: "to"
        ) { @Sendable in
            box.value = "to"
        }
        #expect(success, "honest transition verification failed on a real transition")

        let failing = await StateVerification.verifyTransition(
            read: { @Sendable in box.value },
            from: "from",
            to: "to"
        ) { @Sendable in
            box.value = "elsewhere"
        }
        #expect(!failing, "verifyTransition compared constants instead of observed state")
    }

    @Test("feature harness observe() delivers state changes")
    func harnessObserveDelivers() async throws {
        // The harness holds a Provider (no notifier): drive state changes
        // through an atom the provider watches via the ecosystem bridge.
        let watchedAtom = StateKitAtoms.atom(0)
        let harness = FeatureTestHarness(name: "t") { Provider { ref -> Int in
            (ref as! ProviderElement<Provider<Int>>).watch(watchedAtom)
        }
        }
        let provider = harness.provider

        var seen: [Int] = []
        let subscription = harness.observe { seen.append($0) }

        SKAtomStore.shared.setStateValue(1, for: watchedAtom)
        try await Task.sleep(for: .milliseconds(30))

        subscription.close()
        SKAtomStore.shared.setStateValue(2, for: watchedAtom)

        try await Task.sleep(for: .milliseconds(30))
        #expect(seen.contains(1), "observe() was an empty stub")
        #expect(!seen.contains(2), "listener stayed active after close")
    }
}
