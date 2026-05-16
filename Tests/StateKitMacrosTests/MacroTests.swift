import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macros implementation that we want to test.
@testable import StateKitMacrosPlugin

final class MacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Atom": AtomMacro.self,
        "Provider": NotifierProviderMacro.self,
    ]
    
    func testAtomMacro() throws {
        assertMacroExpansion(
            """
            @Atom var counter: Int = 0
            """,
            expandedSource: """
            var counter: Int = 0
            
            struct _CounterAtom: SKStateAtom, Hashable {
                public typealias Value = Int
                public func defaultValue(context: SKAtomTransactionContext) -> Int  {
                    0
                }
            }
            
            let counterAtom = _CounterAtom()
            """,
            macros: testMacros
        )
    }
    
    func testAtomMacroInference() throws {
        assertMacroExpansion(
            """
            @Atom public var name = "Bob"
            """,
            expandedSource: """
            public var name = "Bob"
            
            public struct _NameAtom: SKStateAtom, Hashable {
                public typealias Value = String
                public func defaultValue(context: SKAtomTransactionContext) -> String  {
                    "Bob"
                }
            }
            
            public let nameAtom = _NameAtom()
            """,
            macros: testMacros
        )
    }
    
    func testProviderMacro() throws {
        assertMacroExpansion(
            """
            @Provider public class CounterNotifier: Notifier<Int> {
                override func build() -> Int { 0 }
            }
            """,
            expandedSource: """
            public class CounterNotifier: Notifier<Int> {
                override func build() -> Int { 0 }
            }
            
            public let counterNotifierProvider = NotifierProvider {
                CounterNotifier()
            }
            """,
            macros: testMacros
        )
    }
}
