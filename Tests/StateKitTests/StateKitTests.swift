import Observation
import Testing
@testable import StateKit
import StateKitTesting

@MainActor
@Suite("useEffect")
struct UseEffectTests {

    @Test("effect runs after render body completes")
    func effectRunsAfterRenderCompletes() {
        let harness = StateTest()
        var steps: [String] = []

        harness.render {
            steps.append("body-start")
            useEffect({
                steps.append("effect")
                return nil
            })
            steps.append("body-end")
        }

        #expect(steps == ["body-start", "body-end", "effect"])
    }

    @Test("dependency change schedules cleanup and new effect after render")
    func dependencyChangeSchedulesCleanupAndNewEffectAfterRender() {
        let harness = StateTest()
        var steps: [String] = []

        let setValue = harness.render {
            let (value, setValue) = useState(0)
            steps.append("render-\(value)-start")
            useEffect({
                steps.append("effect-\(value)")
                return { steps.append("cleanup-\(value)") }
            }, updateStrategy: .preserved(by: value))
            steps.append("render-\(value)-end")
            return setValue
        }

        setValue(1)

        harness.render {
            let (value, _) = useState(0)
            steps.append("render-\(value)-start")
            useEffect({
                steps.append("effect-\(value)")
                return { steps.append("cleanup-\(value)") }
            }, updateStrategy: .preserved(by: value))
            steps.append("render-\(value)-end")
        }

        #expect(steps == [
            "render-0-start",
            "render-0-end",
            "effect-0",
            "render-1-start",
            "render-1-end",
            "cleanup-0",
            "effect-1",
        ])
    }
}

@MainActor
@Suite("useLayoutEffect")
struct UseLayoutEffectTests {

    @Test("layout effect runs after render body completes")
    func layoutEffectRunsAfterRenderCompletes() {
        let harness = StateTest()
        var steps: [String] = []

        harness.render {
            steps.append("body-start")
            useLayoutEffect({
                steps.append("layout")
                return nil
            })
            steps.append("body-end")
        }

        #expect(steps == ["body-start", "body-end", "layout"])
    }

    @Test("layout effects flush before regular effects")
    func layoutEffectsFlushBeforeRegularEffects() {
        let harness = StateTest()
        var steps: [String] = []

        harness.render {
            steps.append("body")
            useEffect({
                steps.append("effect")
                return nil
            })
            useLayoutEffect({
                steps.append("layout")
                return nil
            })
        }

        #expect(steps == ["body", "layout", "effect"])
    }

    @Test("dependency change schedules cleanup and new layout effect before effect phase")
    func dependencyChangeSchedulesCleanupAndNewLayoutEffectBeforeEffectPhase() {
        let harness = StateTest()
        var steps: [String] = []

        let setValue = harness.render {
            let (value, setValue) = useState(0)
            steps.append("render-\(value)-start")
            useLayoutEffect({
                steps.append("layout-\(value)")
                return { steps.append("layout-cleanup-\(value)") }
            }, updateStrategy: .preserved(by: value))
            useEffect({
                steps.append("effect-\(value)")
                return nil
            }, updateStrategy: .preserved(by: value))
            steps.append("render-\(value)-end")
            return setValue
        }

        setValue(1)

        harness.render {
            let (value, _) = useState(0)
            steps.append("render-\(value)-start")
            useLayoutEffect({
                steps.append("layout-\(value)")
                return { steps.append("layout-cleanup-\(value)") }
            }, updateStrategy: .preserved(by: value))
            useEffect({
                steps.append("effect-\(value)")
                return nil
            }, updateStrategy: .preserved(by: value))
            steps.append("render-\(value)-end")
        }

        #expect(steps == [
            "render-0-start",
            "render-0-end",
            "layout-0",
            "effect-0",
            "render-1-start",
            "render-1-end",
            "layout-cleanup-0",
            "layout-1",
            "effect-1",
        ])
    }
}

@Suite("AsyncPhase")
struct AsyncPhaseTests {

    @Test("status reflects the current case")
    func statusReflectsCurrentCase() {
        #expect(AsyncPhase<Int>.idle.status == .idle)
        #expect(AsyncPhase<Int>.loading.status == .loading)
        #expect(AsyncPhase.success(42).status == .success)
        #expect(AsyncPhase<Int>.failure(SampleError()).status == .failure)
    }

    @Test("successValue mirrors value for success only")
    func successValueMirrorsValue() {
        #expect(AsyncPhase.success("done").successValue == "done")
        #expect(AsyncPhase<String>.idle.successValue == nil)
        #expect(AsyncPhase<String>.loading.successValue == nil)
        #expect(AsyncPhase<String>.failure(SampleError()).successValue == nil)
    }

    @Test("pending and terminal helpers match phase semantics")
    func pendingAndTerminalHelpersMatchPhaseSemantics() {
        #expect(AsyncPhase<Int>.idle.isPending == false)
        #expect(AsyncPhase<Int>.loading.isPending == true)
        #expect(AsyncPhase.success(1).isPending == false)
        #expect(AsyncPhase<Int>.failure(SampleError()).isPending == false)

        #expect(AsyncPhase<Int>.idle.isTerminal == false)
        #expect(AsyncPhase<Int>.loading.isTerminal == false)
        #expect(AsyncPhase.success(1).isTerminal == true)
        #expect(AsyncPhase<Int>.failure(SampleError()).isTerminal == true)
    }
}

private struct SampleError: Error {}
private final class TestFlag: @unchecked Sendable {
    var value = false
}

@MainActor
@Suite("useContext")
struct UseContextTests {

    @Test("returns the current HookContext value")
    func returnsCurrentValue() {
        let harness = StateTest()
        let context = HookContext("light")

        let value = harness.render {
            useContext(context)
        }

        #expect(value == "light")
    }

    @Test("reflects HookContext mutations on subsequent renders")
    func reflectsMutationsOnSubsequentRenders() {
        let harness = StateTest()
        let context = HookContext(1)

        let first = harness.render {
            useContext(context)
        }

        context.value = 2

        let second = harness.render {
            useContext(context)
        }

        #expect(first == 1)
        #expect(second == 2)
    }

    @Test("publishes observation changes when value mutates")
    func publishesObservationChangesWhenValueMutates() {
        let context = HookContext(1)
        let didInvalidate = TestFlag()

        withObservationTracking {
            _ = context.value
        } onChange: {
            didInvalidate.value = true
        }

        context.value = 2

        #expect(didInvalidate.value)
    }
}
