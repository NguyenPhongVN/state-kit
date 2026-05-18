import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookFormTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookForm": HookFormMacro.self
    ]

    func testHookFormMacro() {
        assertMacroExpansion(
            "@HookForm struct F { var e: String = \"\" }",
            expandedSource: """
            struct F { var e: String = "" 
            }

            public struct FHook {
                public var e: Binding<String>
                public var eError: Binding<String>

                public var isValid: Bool {
                    eError.wrappedValue.isEmpty
                }

                @discardableResult
                func validate() -> Bool {
                    var allValid = true
                    if e.wrappedValue.isEmpty {
                        eError.wrappedValue = "Required";
                        allValid = false
                    }
                    return allValid
                }

                func reset() {
                    e.wrappedValue = ""
                    eError.wrappedValue = ""
                }
            }

            @MainActor
            func useF() -> FHook {
                FHook(
                    e: StateKit.useBinding(""),
                    eError: StateKit.useBinding("")
                )
            }
            """,
            macros: testMacros
        )
    }
}
