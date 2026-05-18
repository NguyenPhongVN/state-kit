import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import StateKitMacrosPlugin

final class InferenceTests: XCTestCase {
    func testAtomFamilyInference() {
        assertMacroExpansion(
            """
            @AtomFamily
            struct MyAtom {
                let id: Int
                func defaultValue(context: SKAtomTransactionContext) -> Int { id }
            }
            """,
            expandedSource: """
            struct MyAtom {
                let id: Int
                @MainActor
                func defaultValue(context: SKAtomTransactionContext) -> Int { id }
            }

            @MainActor extension MyAtom: SKStateAtom {
                typealias Value = Int
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: ["AtomFamily": AtomFamilyMacro.self]
        )
    }
}
