import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class AsyncHookTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "AsyncHook": AsyncHookMacro.self
    ]

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
                StateKit.useEffect(updateStrategy: .once) {
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
}
