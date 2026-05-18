import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookCallbackTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookCallback": HookCallbackMacro.self
    ]

    func testHookCallbackMacro() {
        assertMacroExpansion(
            "@HookCallback struct C { func call() {} }",
            expandedSource: """
            struct C { func call() {} 
            }

            @MainActor
            func useC() -> () -> Void {
                StateKit.useCallback(updateStrategy: .once) { () in
                    C().call()
                }
            }
            """,
            macros: testMacros
        )
    }
}
