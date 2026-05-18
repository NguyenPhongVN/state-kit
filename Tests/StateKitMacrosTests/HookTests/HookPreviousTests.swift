import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookPreviousTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookPrevious": HookPreviousMacro.self
    ]

    func testHookPreviousMacro() {
        assertMacroExpansion(
            "@HookPrevious struct P { let v: Int }",
            expandedSource: """
            struct P { let v: Int 
            }

            @MainActor
            func useP(v: Int) -> Int? {
                let ref = StateKit.useRef(Int?.none)
                let previous = ref.value
                StateKit.useEffect(updateStrategy: .preserved(by: v)) {
                    ref.value = v
                    return nil
                }
                return previous
            }
            """,
            macros: testMacros
        )
    }
}
