import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookMacrosTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Hook": HookMacro.self,
        "HookState": HookStateMacro.self,
        "HookRef": HookRefMacro.self,
        "HookEffect": HookEffectMacro.self,
        "AsyncHook": AsyncHookMacro.self,
        "Debounce": DebounceMacro.self,
        "Throttle": ThrottleMacro.self,
        "HookPrevious": HookPreviousMacro.self,
        "HookToggle": HookToggleMacro.self,
        "HookInterval": HookIntervalMacro.self,
        "HookMemo": HookMemoMacro.self,
        "HookCallback": HookCallbackMacro.self,
        "HookReducer": HookReducerMacro.self,
        "HookContext": HookContextMacro.self,
        "HookForm": HookFormMacro.self,
        "CustomHook": CustomHookMacro.self
    ]

    func testHookValidation() {
        assertMacroExpansion(
            "@Hook func useCustomHook() {}",
            expandedSource: "func useCustomHook() {}",
            macros: testMacros
        )
    }

    func testHookStateMacro() {
        assertMacroExpansion(
            "@HookState struct S { var count: Int = 0 }",
            expandedSource: """
            struct S { var count: Int = 0 
            }

            @MainActor
            func useS() -> Binding<Int> {
                return useBinding(0)
            }
            """,
            macros: testMacros
        )
    }

    func testHookRefMacro() {
        assertMacroExpansion(
            "@HookRef struct R { var value: Int = 0 }",
            expandedSource: """
            struct R { var value: Int = 0 
            }

            @MainActor
            func useR() -> StateKit.StateRef<Int> {
                return useRef(0)
            }
            """,
            macros: testMacros
        )
    }

    func testHookEffectMacro() {
        assertMacroExpansion(
            """
            @HookEffect
            struct E { func run() async {} }
            """,
            expandedSource: """
            struct E { func run() async {} 
            }

            @MainActor
            func useE() {
                useEffect() {
                let task = Task {
                    await E().run()
                }
                return {
                    task.cancel()
                }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testAsyncHookMacro() {
        assertMacroExpansion(
            """
            @AsyncHook
            struct AH { func run() async {} }
            """,
            expandedSource: """
            struct AH { func run() async {} 
            }

            @MainActor
            func useAH() {
                useEffect(updateStrategy: .once) {
                    let task = Task {
                        let instance = AH()
                        await instance.run()
                    }
                    return {
                        task.cancel()

                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testDebounceMacro() {
        assertMacroExpansion(
            "@Debounce(milliseconds: 100) func d() async {}",
            expandedSource: """
            func d() async {}

            @MainActor
            private var _dTask: Task<Void, Never>?

            @MainActor
            func d_debounced() {
                _dTask?.cancel()
                _dTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(100) * 1_000_000)
                    if !Task.isCancelled {
                        await d()
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testThrottleMacro() {
        assertMacroExpansion(
            "@Throttle(milliseconds: 100) func t() async {}",
            expandedSource: """
            func t() async {}

            @MainActor
            private var _tLastExecution: Date = Date(timeIntervalSince1970: 0)

            @MainActor
            func t_throttled() {
                let now = Date()
                let interval = TimeInterval(100) / 1000.0

                if now.timeIntervalSince(_tLastExecution) >= interval {
                    _tLastExecution = now
                    Task {
                        await t()
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testHookPreviousMacro() {
        assertMacroExpansion(
            "@HookPrevious struct P { let v: Int }",
            expandedSource: """
            struct P { let v: Int 
            }

            @MainActor
            func useP(v: Int) -> Int? {
                let ref = useRef(Int?.none)
                let previous = ref.value
                useEffect(updateStrategy: .preserved(by: v)) {
                    ref.value = v
                    return nil
                }
                return previous
            }
            """,
            macros: testMacros
        )
    }

    func testHookToggleMacro() {
        assertMacroExpansion(
            "@HookToggle struct T {}",
            expandedSource: """
            struct T {}

            @MainActor
            func useT() -> (Bool, () -> Void) {
                let (value, setValue) = useState(false)
                let toggle = {
                    setValue(!value)
                }
                return (value, toggle)
            }
            """,
            macros: testMacros
        )
    }

    func testHookIntervalMacro() {
        assertMacroExpansion(
            """
            @HookInterval
            struct I { var intervalMs: Int; func tick() async {} }
            """,
            expandedSource: """
            struct I { var intervalMs: Int; func tick() async {} 
            }

            @MainActor
            func useI(intervalMs: Int) {
                useEffect(updateStrategy: .preserved(by: intervalMs)) {
                    let instance = I(
                intervalMs: intervalMs
                )
                    let task = Task {
                        while !Task.isCancelled {
                            try? await Task.sleep(nanoseconds: UInt64(instance.intervalMs) * 1_000_000)
                            if !Task.isCancelled {
                                await instance.tick()
                            }
                        }
                    }
                    return {
                        task.cancel()
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testHookMemoMacro() {
        assertMacroExpansion(
            "@HookMemo struct M { func compute() -> Int { 0 } }",
            expandedSource: """
            struct M { func compute() -> Int { 0 } 
            }

            @MainActor
            func useMMemo() -> Int  {
                useMemo(updateStrategy: .once) {
                    M().compute()
                }
            }
            """,
            macros: testMacros
        )
    }

    func testHookCallbackMacro() {
        assertMacroExpansion(
            "@HookCallback struct C { func call() {} }",
            expandedSource: """
            struct C { func call() {} 
            }

            @MainActor
            func useCCallback() -> () -> Void {
                useCallback(updateStrategy: .once) { () in
                    C().call()
                }
            }
            """,
            macros: testMacros
        )
    }

    func testHookReducerMacro() {
        assertMacroExpansion(
            """
            @HookReducer
            struct Red { typealias State = Int; typealias Action = Void; func reduce(_ s: inout Int, action: Void) {} }
            """,
            expandedSource: """
            struct Red { typealias State = Int; typealias Action = Void; func reduce(_ s: inout Int, action: Void) {} 
            }

            @MainActor
            func useRed(initial: Int = Int()) -> (Int, (Void) -> Void) {
                let reducer = Red()
                return useReducer(initial) { state, action in
                    reducer.reduce(&state, action: action)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testHookContextMacro() {
        assertMacroExpansion(
            "@HookContext struct Ctx { var v: Int = 0 }",
            expandedSource: """
            struct Ctx { var v: Int = 0 
            }

            @MainActor
            let ctxHookContext = StateKit.HookContext<Ctx>(Ctx())

            @MainActor
            func useCtxContext() -> Ctx {
                useContext(ctxHookContext)
            }
            """,
            macros: testMacros
        )
    }

    func testHookFormMacro() {
        assertMacroExpansion(
            "@HookForm struct F { var e: String = \"\" }",
            expandedSource: """
            struct F { var e: String = "" 
            }

            public struct FHook {
                public var e: Binding<String>
                public var eError: Binding<String>

                public var isValid: Bool {
                    eError.wrappedValue.isEmpty
                }

                @discardableResult
                func validate() -> Bool {
                    // Basic validation: all fields must not be empty if they are Strings
                    var allValid = true
                    if e.wrappedValue.isEmpty {
                        eError.wrappedValue = "Required";
                        allValid = false
                    }
                    return allValid
                }

                func reset() {
                    e.wrappedValue = ""
                    eError.wrappedValue = ""
                }
            }

            @MainActor
            func useF() -> FHook {
                FHook(
                    e: useBinding(""),
                    eError: useBinding("")
                )
            }
            """,
            macros: testMacros
        )
    }

    func testCustomHookValidation() {
        assertMacroExpansion(
            "@CustomHook func useMyCustom() {}",
            expandedSource: "func useMyCustom() {}",
            macros: testMacros
        )
    }
}
