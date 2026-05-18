import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookToggleTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookToggle": HookToggleMacro.self
    ]

    func testHookToggleMacro() {
        assertMacroExpansion(
            "@HookToggle struct T {}",
            expandedSource: """
            struct T {}

            @MainActor
            func useT() -> (Bool, () -> Void) {
                let (value, setValue) = StateKit.useState(false)
                let toggle = {
                    setValue(!value)
                }
                return (value, toggle)
            }
            """,
            macros: testMacros
        )
    }

    func testHookTogglePrivateAccess() {
        assertMacroExpansion(
            "@HookToggle private struct T {}",
            expandedSource: """
            private struct T {}

            @MainActor
            private func useT() -> (Bool, () -> Void) {
                let (value, setValue) = StateKit.useState(false)
                let toggle = {
                    setValue(!value)
                }
                return (value, toggle)
            }
            """,
            macros: testMacros
        )
    }
}
