import Testing
import Foundation
import Riverpods
import StateKitTesting

// Spec 012 US5: the testing-support module had zero test coverage despite being
// the module other tests rely on. Pin its core contracts.

@MainActor
@Suite("StateKitTesting — DeterministicTestEnvironment")
struct DeterministicEnvironmentTests {

    @Test("freezeTime pins now(); advance moves it deterministically")
    func timeControl() {
        let env = DeterministicTestEnvironment(seed: 7)
        let base = Date(timeIntervalSince1970: 1_000)

        env.freezeTime(to: base)
        #expect(env.now() == base, "now() must return the frozen time")

        env.advance(by: 30)
        #expect(env.now() == base.addingTimeInterval(30), "advance must move frozen time forward exactly")
    }

    @Test("same seed yields identical random sequences within bounds")
    func randomDeterminism() {
        let a = DeterministicTestEnvironment(seed: 42)
        let b = DeterministicTestEnvironment(seed: 42)

        let seqA = (0..<20).map { _ in a.nextInt(min: 0, max: 100) }
        let seqB = (0..<20).map { _ in b.nextInt(min: 0, max: 100) }

        #expect(seqA == seqB, "same seed must reproduce the same sequence")
        #expect(seqA.allSatisfy { $0 >= 0 && $0 <= 100 }, "values must respect the requested bounds")
    }

    @Test("enqueueAsync drains the queued operation")
    func asyncDrain() async {
        let env = DeterministicTestEnvironment(seed: 1)
        let done = DrainBox()

        await env.enqueueAsync { done.value = true }

        #expect(done.value, "queued operation must have run after drain")
    }
}

@MainActor
@Suite("StateKitTesting — IntegrationTestEnvironment")
struct IntegrationBuilderTests {

    @Test("builder applies value overrides into the built container")
    func builderOverrides() {
        let p = Provider { _ in "real" }
        let mock = Provider { _ in "mock" }

        var setupRan = false
        let container = IntegrationTestEnvironment()
            .override(p, with: "mock")
            .onSetup { setupRan = true }
            .build()

        #expect(container.read(p) == "mock", "override must be served by the built container")
        #expect(setupRan, "onSetup callbacks must run during build")
    }
}

private final class DrainBox: @unchecked Sendable {
    var value = false
}
