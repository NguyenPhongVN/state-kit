import Testing
@testable import StateKit
import StateKitTesting

@Test @MainActor
func useState_persistsAcrossRenders() {
    let harness = HookTest()

    // First render: state should be initialized with the given initial value.
    let first = harness.render {
        useState(0).value
    }
    #expect(first == 0)

    // Second render: increment the state.
    let second = harness.render {
        let signal = useState(0)
        signal.value += 1
        return signal.value
    }
    #expect(second == 1)

    // Third render: the previously incremented state should be preserved.
    let third = harness.render {
        useState(0).value
    }
    #expect(third == 1)
}

@Test @MainActor
func useMemo_recomputesOnlyWhenDepsChange() {
    let harness = HookTest()
    var computeCount = 0

    let first = harness.render {
        useMemo({
            computeCount += 1
            return "v\(computeCount)"
        }, deps: [1])
    }
    #expect(first == "v1")
    #expect(computeCount == 1)

    let second = harness.render {
        useMemo({
            computeCount += 1
            return "v\(computeCount)"
        }, deps: [1])
    }
    #expect(second == "v1")
    #expect(computeCount == 1)

    let third = harness.render {
        useMemo({
            computeCount += 1
            return "v\(computeCount)"
        }, deps: [2])
    }
    #expect(third == "v2")
    #expect(computeCount == 2)
}

@Test @MainActor
func useRef_persistsValueAcrossRenders() {
    let harness = HookTest()

    let first = harness.render {
        useRef(0).value
    }
    #expect(first == 0)

    let second = harness.render {
        let ref = useRef(999) // initial should be ignored after first render
        ref.value = 42
        return ref.value
    }
    #expect(second == 42)

    let third = harness.render {
        useRef(-1).value // initial should still be ignored
    }
    #expect(third == 42)
}


@Test @MainActor
func combinedHooks_workTogetherAcrossRenders() {
    let harness = HookTest()
    var computeCount = 0

    // First render: initialize all hooks
    let first = harness.render {
        let state = useState(1)
        let ref = useRef("start")
        let memo = useMemo({
            computeCount += 1
            return state.value * 10
        }, deps: [state.value])
        // mutate ref but not state yet
        ref.value = "first"
        return (state.value, ref.value, memo)
    }
    #expect(first.0 == 1)
    #expect(first.1 == "first")
    #expect(first.2 == 10)
    #expect(computeCount == 1)

    // Second render: update state; memo should recompute because deps changed
    let second = harness.render {
        let state = useState(0) // initial ignored; should get previous value 1
        let ref = useRef("ignored")
        state.value += 2 // now 3
        let memo = useMemo({
            computeCount += 1
            return state.value * 10
        }, deps: [state.value])
        // update ref again
        ref.value = "second"
        return (state.value, ref.value, memo)
    }
    #expect(second.0 == 3)
    #expect(second.1 == "second")
    #expect(second.2 == 30)
    #expect(computeCount == 2)

    // Third render: no state change; memo should NOT recompute
    let third = harness.render {
        let state = useState(0)
        let ref = useRef("ignored")
        let memo = useMemo({
            computeCount += 1
            return state.value * 10
        }, deps: [state.value])
        return (state.value, ref.value, memo)
    }
    #expect(third.0 == 3)
    #expect(third.1 == "second")
    #expect(third.2 == 30)
    #expect(computeCount == 2)
}

