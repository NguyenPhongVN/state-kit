import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookStateTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookState": HookStateMacro.self
    ]

    func testHookStateWithDefault() {
        assertMacroExpansion(
            "@HookState struct S { var count: Int = 0 }",
            expandedSource: """
            struct S { var count: Int = 0 
            }

            @MainActor
            func useS(count: Int = 0) -> Binding<S> {
                return StateKit.useBinding(S(count: count))
            }
            """,
            macros: testMacros
        )
    }

    func testHookStateNoDefault() {
        assertMacroExpansion(
            "@HookState struct S { var count: Int }",
            expandedSource: """
            struct S { var count: Int 
            }

            @MainActor
            func useS(count: Int) -> Binding<S> {
                return StateKit.useBinding(S(count: count))
            }
            """,
            macros: testMacros
        )
    }

    func testHookStateMultipleProperties() {
        assertMacroExpansion(
            "@HookState struct S { var name: String = \"\"; var age: Int = 0 }",
            expandedSource: """
            struct S { var name: String = \"\"; var age: Int = 0 
            }

            @MainActor
            func useS(name: String = \"\", age: Int = 0) -> Binding<S> {
                return StateKit.useBinding(S(name: name, age: age))
            }
            """,
            macros: testMacros
        )
    }

    func testHookStatePrivateAccess() {
        assertMacroExpansion(
            "@HookState private struct S { var count: Int = 0 }",
            expandedSource: """
            private struct S { var count: Int = 0 
            }

            @MainActor
            fileprivate func useS(count: Int = 0) -> Binding<S> {
                return StateKit.useBinding(S(count: count))
            }
            """,
            macros: testMacros
        )
    }

    func testHookStateSkipsComputedProperties() {
        assertMacroExpansion(
            """
            @HookState struct S {
                var count: Int = 0
                var doubled: Int { count * 2 }
            }
            """,
            expandedSource: """
            struct S {
                var count: Int = 0
                var doubled: Int { count * 2 }
            }

            @MainActor
            func useS(count: Int = 0) -> Binding<S> {
                return StateKit.useBinding(S(count: count))
            }
            """,
            macros: testMacros
        )
    }
}
