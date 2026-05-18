import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class ViewMacrosTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "HookView": HookViewMacro.self,
        "StateView": StateViewMacro.self,
        "AsyncView": AsyncViewMacro.self
    ]

    func testHookViewMacro() {
        assertMacroExpansion(
            """
            @HookView
            struct MyView: View {
                var stateBody: some View { Text("Hi") }
            }
            """,
            expandedSource: """
            struct MyView: View {
                var stateBody: some View { Text("Hi") }

                var body: some View {
                    StateScope {
                        stateBody
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testStateViewMacro() {
        assertMacroExpansion(
            """
            @StateView
            struct MyView: View {
                var stateBody: some View { Text("Hi") }
            }
            """,
            expandedSource: """
            struct MyView: View {
                var stateBody: some View { Text("Hi") }

                var body: some View {
                    StateScope {
                        stateBody
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testAsyncViewMacro() {
        assertMacroExpansion(
            """
            @AsyncView(atom: myAtom)
            struct MyView: View {
                var stateBody: some View { Text("Loaded") }
            }
            """,
            expandedSource: """
            struct MyView: View {
                var stateBody: some View { Text("Loaded") }

                var body: some View {
                    stateBody
                }

                var isLoading: Bool {
                    true  // User implements based on phase
                }

                var hasError: Bool {
                    false  // User implements based on phase
                }
            }
            """,
            macros: testMacros
        )
    }
}
