import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookMemoTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookMemo": HookMemoMacro.self
    ]

    func testHookMemoMacro() {
        assertMacroExpansion(
            "@HookMemo struct M { func compute() -> Int { 0 } }",
            expandedSource: """
            struct M { func compute() -> Int { 0 } 
            }

            @MainActor
            func useM() -> Int {
                StateKit.useMemo(updateStrategy: .once) {
                    M().compute()
                }
            }
            """,
            macros: testMacros
        )
    }
}
