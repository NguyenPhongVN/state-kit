import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookContextTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookContext": HookContextMacro.self
    ]

    func testHookContextMacro() {
        assertMacroExpansion(
            "@HookContext struct Ctx { var v: Int = 0 }",
            expandedSource: """
            struct Ctx { var v: Int = 0 
            }

            @MainActor
            let _hookContext = StateKit.HookContext<Ctx>(Ctx())

            @MainActor
            func useCtx() -> Ctx {
                useContext(_hookContext)
            }
            """,
            macros: testMacros
        )
    }
}
