import Testing
import StateKit
import StateKitTesting
import Foundation

@Suite("StateKit — Basic Hooks")
@MainActor
struct HookTests {
    
    @Test("useState initial value and updates")
    func testUseState() {
        let h = StateTest()
        
        // Initial render
        var (count, setCount) = h.render { useState(0) }
        #expect(count == 0)
        
        // Update state
        setCount(5)
        
        // Re-render
        (count, setCount) = h.render { useState(0) }
        #expect(count == 5)
    }
    
    @Test("useReducer works correctly")
    func testUseReducer() {
        let h = StateTest()
        
        enum Action { case increment, decrement }
        
        // Initial render
        var (count, dispatch) = h.render { 
            useReducer(10) { (state: inout Int, action: Action) in
                switch action {
                case .increment: state += 1
                case .decrement: state -= 1
                }
            }
        }
        #expect(count == 10)
        
        // Dispatch actions
        dispatch(.increment)
        (count, dispatch) = h.render { 
            useReducer(10) { (state: inout Int, action: Action) in
                switch action {
                case .increment: state += 1
                case .decrement: state -= 1
                }
            }
        }
        #expect(count == 11)
        
        dispatch(.decrement)
        dispatch(.decrement)
        (count, dispatch) = h.render { 
            useReducer(10) { (state: inout Int, action: Action) in
                switch action {
                case .increment: state += 1
                case .decrement: state -= 1
                }
            }
        }
        #expect(count == 9)
    }
    
    @Test("useMemo caches values")
    func testUseMemo() {
        let h = StateTest()
        var computeCount = 0
        
        func render(dep: Int) -> Int {
            h.render {
                useMemo(updateStrategy: .preserved(by: dep)) {
                    computeCount += 1
                    return dep * 2
                }
            }
        }
        
        #expect(render(dep: 1) == 2)
        #expect(computeCount == 1)
        
        // Same dep, should not recompute
        #expect(render(dep: 1) == 2)
        #expect(computeCount == 1)
        
        // New dep, should recompute
        #expect(render(dep: 2) == 4)
        #expect(computeCount == 2)
    }
    
    @Test("useRef persists values across renders")
    func testUseRef() {
        let h = StateTest()
        
        func render() -> Int {
            let ref = h.render { useRef(0) }
            return ref.value
        }
        
        #expect(render() == 0)
        
        // Update ref directly
        let ref = h.render { useRef(0) }
        ref.value = 42
        
        #expect(render() == 42)
    }
    
    @Test("useCallback returns same closure instance")
    func testUseCallback() {
        let h = StateTest()
        
        func getCallback(dep: Int) -> () -> Int {
            h.render {
                useCallback(updateStrategy: .preserved(by: dep)) {
                    dep * 10
                }
            }
        }
        
        let cb1 = getCallback(dep: 1)
        let cb2 = getCallback(dep: 1)
        let cb3 = getCallback(dep: 2)
        
        #expect(cb1() == 10)
        #expect(cb2() == 10)
        #expect(cb3() == 20)
    }
    
    @Test("useEffect runs and cleans up")
    func testUseEffect() {
        let h = StateTest()
        var runCount = 0
        var cleanupCount = 0
        
        func render(dep: Int) {
            h.render {
                useEffect(updateStrategy: .preserved(by: dep)) {
                    runCount += 1
                    return { cleanupCount += 1 }
                }
            }
        }
        
        // First render
        render(dep: 1)
        #expect(runCount == 1)
        #expect(cleanupCount == 0)
        
        // Same dep, should not run or cleanup
        render(dep: 1)
        #expect(runCount == 1)
        #expect(cleanupCount == 0)
        
        // Change dep, should cleanup then run
        render(dep: 2)
        #expect(runCount == 2)
        #expect(cleanupCount == 1)
        
        // Reset (simulates unmount), should cleanup last effect
        h.reset()
        #expect(cleanupCount == 2)
    }

    @Test("useOnChange only runs when value changes")
    func testUseOnChange() {
        let h = StateTest()
        var changeCount = 0
        
        func render(value: Int) {
            h.render {
                useOnChange(value) { old, new in
                    changeCount += 1
                }
            }
        }
        
        // First render, should NOT run
        render(value: 1)
        #expect(changeCount == 0)
        
        // Same value, should NOT run
        render(value: 1)
        #expect(changeCount == 0)
        
        // Different value, should run
        render(value: 2)
        #expect(changeCount == 1)
        
        render(value: 3)
        #expect(changeCount == 2)
    }

    @Test("useAsync runs task and updates phase")
    func testUseAsync() async {
        let h = StateTest()
        
        let phase1 = h.render {
            useAsync(updateStrategy: .once) {
                try await Task.sleep(nanoseconds: 10_000_000)
                return "Done"
            }
        }
        #expect(phase1 == .loading)
        
        // Wait for task to finish
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let phase2 = h.render {
            useAsync(updateStrategy: .once) { "Done" }
        }
        #expect(phase2 == .success("Done"))
    }
}
