import Testing
import SwiftUI
import StateKit
import StateKitTesting
import StateKitMacros

@HookRef struct RefCounter { var value: Int = 0 }
@HookState struct CountState { var count: Int = 0 }
@HookToggle struct EditMode {}
@HookMemo struct DoubleCompute { func compute() -> Int { 42 } }
@HookReducer struct MathReducer {
    typealias State = Int
    typealias Action = String
    func reduce(_ s: inout Int, action: String) {
        if action == "add" { s += 1 }
    }
}
@HookCallback struct GreetHandler { func call(_ name: String) -> String { "Hello, \(name)!" } }
@HookPrevious struct ScoreTracker { let score: Int }
@HookForm struct ProfileForm { var name: String = ""; var bio: String = "" }

@Suite("Hook Macros — Runtime")
@MainActor
struct HookMacroRuntimeTests {

    @Test("HookRef: useRef persists")
    func hookRef() {
        let h = StateTest()
        let ref = h.render { useRefCounter(value: 0) }
        #expect(ref.value.value == 0)
        ref.value = RefCounter(value: 42)
        let ref2 = h.render { useRefCounter(value: 0) }
        #expect(ref2.value.value == 42)
    }

    @Test("HookState: binding state")
    func hookState() {
        let h = StateTest()
        let binding = h.render { useCountState(count: 0) }
        #expect(binding.wrappedValue.count == 0)
        binding.wrappedValue = CountState(count: 7)
        let binding2 = h.render { useCountState(count: 0) }
        #expect(binding2.wrappedValue.count == 7)
    }

    @Test("HookToggle: toggle toggles")
    func hookToggle() {
        let h = StateTest()
        var (value, toggle) = h.render { useEditMode() }
        #expect(value == false)
        toggle()
        (value, toggle) = h.render { useEditMode() }
        #expect(value == true)
        toggle()
        (value, toggle) = h.render { useEditMode() }
        #expect(value == false)
    }

    @Test("HookMemo: memoization")
    func hookMemo() {
        let h = StateTest()
        let result = h.render { useDoubleCompute() }
        #expect(result == 42)
    }

    @Test("HookReducer: reducer works")
    func hookReducer() {
        let h = StateTest()
        var (count, dispatch) = h.render { useMathReducer(initial: 10) }
        #expect(count == 10)
        dispatch("add")
        (count, dispatch) = h.render { useMathReducer(initial: 10) }
        #expect(count == 11)
    }

    @Test("HookCallback: callback returns value")
    func hookCallback() {
        let h = StateTest()
        let cb = h.render { useGreetHandler() }
        #expect(cb("World") == "Hello, World!")
    }

    @Test("HookPrevious: tracks previous value")
    func hookPrevious() {
        let h = StateTest()
        let prev1 = h.render { useScoreTracker(score: 10) }
        #expect(prev1 == nil)
        let prev2 = h.render { useScoreTracker(score: 20) }
        #expect(prev2 == 10)
    }

    @Test("HookForm: form fields")
    func hookForm() {
        let h = StateTest()
        let form = h.render { useProfileForm() }
        #expect(form.name.wrappedValue == "")
        #expect(form.isValid == true)
        form.name.wrappedValue = "Alice"
        #expect(form.isValid == true)
    }
}
