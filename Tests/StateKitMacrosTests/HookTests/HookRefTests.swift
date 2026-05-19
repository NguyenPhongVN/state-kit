import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookRefTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookRef": HookRefMacro.self
    ]

    func testHookRefMacroWithDefault() {
        assertMacroExpansion(
            """
            @HookRef struct R { var value: Int = 0 }
            """,
            expandedSource: """
            struct R { var value: Int = 0 
            }

            @MainActor
            func useR(value: Int = 0) -> StateKit.StateRef<R> {
                return StateKit.useRef(R(value: value))
            }
            """,
            macros: testMacros
        )
    }

    func testHookRefMacroNoDefault() {
        assertMacroExpansion(
            """
            @HookRef struct R { var value: Int }
            """,
            expandedSource: """
            struct R { var value: Int 
            }

            @MainActor
            func useR(value: Int) -> StateKit.StateRef<R> {
                return StateKit.useRef(R(value: value))
            }
            """,
            macros: testMacros
        )
    }

    func testHookRefMacroNoProperties() {
        assertMacroExpansion(
            """
            @HookRef struct R {}
            """,
            expandedSource: """
            struct R {}

            @MainActor
            func useR() -> StateKit.StateRef<R> {
                return StateKit.useRef(R())
            }
            """,
            macros: testMacros
        )
    }

    func testHookRefPrivateAccess() {
        assertMacroExpansion(
            """
            @HookRef private struct R { var value: Int = 0 }
            """,
            expandedSource: """
            private struct R { var value: Int = 0 
            }

            @MainActor
            fileprivate func useR(value: Int = 0) -> StateKit.StateRef<R> {
                return StateKit.useRef(R(value: value))
            }
            """,
            macros: testMacros
        )
    }

    func testHookRefPublicAccess() {
        assertMacroExpansion(
            """
            @HookRef public struct R { var value: Int = 0 }
            """,
            expandedSource: """
            public struct R { var value: Int = 0 
            }

            @MainActor
            public func useR(value: Int = 0) -> StateKit.StateRef<R> {
                return StateKit.useRef(R(value: value))
            }
            """,
            macros: testMacros
        )
    }

    func testHookRefSkipsComputedProperties() {
        assertMacroExpansion(
            """
            @HookRef struct R {
                var value: Int = 0
                var doubled: Int { value * 2 }
            }
            """,
            expandedSource: """
            struct R {
                var value: Int = 0
                var doubled: Int { value * 2 }
            }

            @MainActor
            func useR(value: Int = 0) -> StateKit.StateRef<R> {
                return StateKit.useRef(R(value: value))
            }
            """,
            macros: testMacros
        )
    }
}
