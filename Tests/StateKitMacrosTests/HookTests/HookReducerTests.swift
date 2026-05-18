import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookReducerTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookReducer": HookReducerMacro.self
    ]

    func testHookReducerMacro() {
        assertMacroExpansion(
            """
            @HookReducer
            struct Red { typealias State = Int; typealias Action = Void; func reduce(_ s: inout Int, action: Void) {} }
            """,
            expandedSource: """
            struct Red { typealias State = Int; typealias Action = Void; func reduce(_ s: inout Int, action: Void) {} 
            }

            @MainActor
            func useRed(initial: Int = Int()) -> (Int, (Void) -> Void) {
                let reducer = Red()
                return StateKit.useReducer(initial) { state, action in
                    reducer.reduce(&state, action: action)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testHookReducerPrivateAccess() {
        assertMacroExpansion(
            """
            @HookReducer private struct Red { typealias State = Int; typealias Action = Void; func reduce(_ s: inout Int, action: Void) {} }
            """,
            expandedSource: """
            private struct Red { typealias State = Int; typealias Action = Void; func reduce(_ s: inout Int, action: Void) {} 
            }

            @MainActor
            private func useRed(initial: Int = Int()) -> (Int, (Void) -> Void) {
                let reducer = Red()
                return StateKit.useReducer(initial) { state, action in
                    reducer.reduce(&state, action: action)
                }
            }
            """,
            macros: testMacros
        )
    }
}
