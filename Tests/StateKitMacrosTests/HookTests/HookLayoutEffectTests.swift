import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookLayoutEffectTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookLayoutEffect": HookLayoutEffectMacro.self
    ]

    func testHookLayoutEffectMacro() {
        assertMacroExpansion(
            """
            @HookLayoutEffect
            struct E { func run() {} }
            """,
            expandedSource: """
            struct E { func run() {} 
            }

            @MainActor
            func useE() {
                StateKit.useLayoutEffect() {
                E().run()
                return nil
                }
            }
            """,
            macros: testMacros
        )
    }
}
