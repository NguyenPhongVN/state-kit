import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookEffectTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookEffect": HookEffectMacro.self
    ]

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
                StateKit.useEffect() {
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
}
