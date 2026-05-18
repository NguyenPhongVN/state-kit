import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookValidationTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "Hook": CheckHookFunctionMacro.self
    ]

    func testHookValidation() {
        assertMacroExpansion(
            "@Hook func useCustomHook() {}",
            expandedSource: "func useCustomHook() {}",
            macros: testMacros
        )
    }
}
