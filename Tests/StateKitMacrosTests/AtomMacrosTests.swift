import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class AtomMacrosTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "StateAtom": StateAtomMacro.self,
        "ValueAtom": ValueAtomMacro.self,
        "TaskAtom": TaskAtomMacro.self,
        "ThrowingTaskAtom": TaskAtomMacro.self,
        "PublisherAtom": PublisherAtomMacro.self,
        "Atom": AtomMacro.self,
        "AtomFamily": AtomFamilyMacro.self,
        "SelectorFamily": SelectorFamilyMacro.self,
        "AsyncTaskFamily": AsyncTaskFamilyMacro.self,
        "AtomReducer": AtomReducerMacro.self,
        "Computed": ComputedMacro.self,
        "SelectorAtom": SelectorAtomMacro.self,
        "FilteredAtom": FilteredAtomMacro.self,
        "MappedAtom": MappedAtomMacro.self,
        "CombineAtom": CombineAtomMacro.self,
        "DistinctAtom": DistinctAtomMacro.self,
        "FlatMapAtom": FlatMapAtomMacro.self
    ]

    func testStateAtomMacro() {
        assertMacroExpansion(
            "@StateAtom struct MyAtom { func defaultValue(context: SKAtomTransactionContext) -> Int { 0 } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc defaultValue(context: SKAtomTransactionContext) -> Int { 0 } 

                typealias Value = Int
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKStateAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testValueAtomMacro() {
        assertMacroExpansion(
            "@ValueAtom struct MyAtom { func value(context: SKAtomTransactionContext) -> String { \"\" } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc value(context: SKAtomTransactionContext) -> String { "" } 

                typealias Value = String
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKValueAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testTaskAtomMacro() {
        assertMacroExpansion(
            "@TaskAtom struct MyAtom { func task(context: SKAtomTransactionContext) async -> Int { 0 } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc task(context: SKAtomTransactionContext) async -> Int { 0 } 

                typealias TaskSuccess = Int
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKTaskAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testThrowingTaskAtomMacro() {
        assertMacroExpansion(
            "@ThrowingTaskAtom struct MyAtom { func task(context: SKAtomTransactionContext) async throws -> Int { 0 } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc task(context: SKAtomTransactionContext) async throws -> Int { 0 } 

                typealias TaskSuccess = Int
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKThrowingTaskAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testPublisherAtomMacro() {
        assertMacroExpansion(
            """
            @PublisherAtom
            struct MyAtom {
                func publisher(context: SKAtomTransactionContext) -> AnyPublisher<Int, Error> {
                    Empty().eraseToAnyPublisher()
                }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func publisher(context: SKAtomTransactionContext) -> AnyPublisher<Int, Error> {
                    Empty().eraseToAnyPublisher()
                }

                typealias PublisherOutput = Int

                typealias AtomPublisher = AnyPublisher<Int, Error>
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKPublisherAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testUnifiedAtomMacro() {
        assertMacroExpansion(
            "@Atom struct MyAtom { func defaultValue(context: SKAtomTransactionContext) -> Int { 0 } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc defaultValue(context: SKAtomTransactionContext) -> Int { 0 } 

                typealias Value = Int
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKStateAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testAtomFamilyMacro() {
        assertMacroExpansion(
            """
            @AtomFamily
            struct UserAtom {
                let id: String
                func defaultValue(context: SKAtomTransactionContext) -> String { id }
            }
            """,
            expandedSource: """
            struct UserAtom {
                let id: String
                @MainActor
                func defaultValue(context: SKAtomTransactionContext) -> String { id }

                typealias Value = String
                @MainActor
                public static let family = atomFamily { (id: String) in
                    UserAtom(id: id)
                }
            }

            extension UserAtom: SKStateAtom {
            }

            extension UserAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testSelectorFamilyMacro() {
        assertMacroExpansion(
            """
            @SelectorFamily
            struct UserSelector {
                let id: String
                func value(context: SKAtomTransactionContext) -> String { id }
            }
            """,
            expandedSource: """
            struct UserSelector {
                let id: String
                @MainActor
                func value(context: SKAtomTransactionContext) -> String { id }

                typealias Value = String
                @MainActor
                public static let family = atomFamily { (id: String, context: SKAtomTransactionContext) in
                    UserSelector(id: id).value(context: context)
                }
            }

            extension UserSelector: SKValueAtom {
            }

            extension UserSelector: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testAsyncTaskFamilyMacro() {
        assertMacroExpansion(
            """
            @AsyncTaskFamily
            struct UserTask {
                let id: Int
                func task(context: SKAtomTransactionContext) async -> Int { id }
            }
            """,
            expandedSource: """
            struct UserTask {
                let id: Int
                @MainActor
                func task(context: SKAtomTransactionContext) async -> Int { id }

                typealias Value = Int
                @MainActor
                public static let family = atomFamily { (id: Int) in
                    UserTask(id: id)
                }
            }

            extension UserTask: SKTaskAtom {
            }

            extension UserTask: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testAtomReducerMacro() {
        assertMacroExpansion(
            """
            @AtomReducer
            struct MyReducer {
                typealias State = Int
                typealias Action = Void
                func reduce(_ state: inout Int, action: Void) {}
            }
            """,
            expandedSource: """
            struct MyReducer {
                typealias State = Int
                typealias Action = Void
                func reduce(_ state: inout Int, action: Void) {}

                struct MyReducerAtom: SKStateAtom, Hashable {
                    typealias Value = Int

                    private let reducer = MyReducer()

                    @MainActor
                    func defaultValue(context: SKAtomTransactionContext) -> Int {
                        Int()
                    }

                    @MainActor
                    func reduce(_ state: inout Int, action: Void) {
                        reducer.reduce(&state, action: action)
                    }
                }
                @MainActor
                public static let shared = MyReducerAtom()
            }
            """,
            macros: testMacros
        )
    }

    func testComputedMacro() {
        assertMacroExpansion(
            "@Computed struct MyAtom { func compute(context: SKAtomTransactionContext) -> Int { 0 } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc compute(context: SKAtomTransactionContext) -> Int { 0 } 

                typealias Value = Int

                @MainActor
                func value(context: SKAtomTransactionContext) -> Value {
                    compute(context: context)
                }
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKValueAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testSelectorAtomMacro() {
        assertMacroExpansion(
            "@SelectorAtom struct MyAtom { func select(context: SKAtomTransactionContext) -> Int { 0 } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc select(context: SKAtomTransactionContext) -> Int { 0 } 

                typealias Value = Int

                @MainActor
                func value(context: SKAtomTransactionContext) -> Value {
                    select(context: context)
                }
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKValueAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testFilteredAtomMacro() {
        assertMacroExpansion(
            "@FilteredAtom struct MyAtom { func predicate(_ v: Int) -> Bool { true } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc predicate(_ v: Int) -> Bool { true } 

                typealias Value = [Any]

                @MainActor
                func value(context: SKAtomTransactionContext) -> Value {
                    // Placeholder implementation
                    fatalError("value(context:) must be implemented by user")
                }
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKValueAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testMappedAtomMacro() {
        assertMacroExpansion(
            "@MappedAtom struct MyAtom { func transform(_ v: Int) -> String { \"\" } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc transform(_ v: Int) -> String { "" } 

                typealias Value = String

                @MainActor
                func value(context: SKAtomTransactionContext) -> Value {
                    // Placeholder implementation
                    fatalError("value(context:) must be implemented by user")
                }
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKValueAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testCombineAtomMacro() {
        assertMacroExpansion(
            "@CombineAtom struct MyAtom { func combine(context: SKAtomTransactionContext) -> Int { 0 } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc combine(context: SKAtomTransactionContext) -> Int { 0 } 

                typealias Value = Int

                @MainActor
                func value(context: SKAtomTransactionContext) -> Value {
                    combine(context: context)
                }
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKValueAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testDistinctAtomMacro() {
        assertMacroExpansion(
            "@DistinctAtom struct MyAtom { func source(context: SKAtomTransactionContext) -> Int { 0 } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc source(context: SKAtomTransactionContext) -> Int { 0 } 

                typealias Value = Int

                @MainActor
                func value(context: SKAtomTransactionContext) -> Value {
                    source(context: context)
                }
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKValueAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testFlatMapAtomMacro() {
        assertMacroExpansion(
            "@FlatMapAtom struct MyAtom { func flatMap(context: SKAtomTransactionContext) -> Int { 0 } }",
            expandedSource: """
            struct MyAtom { 
            @MainActorfunc flatMap(context: SKAtomTransactionContext) -> Int { 0 } 

                typealias Value = Int

                @MainActor
                func value(context: SKAtomTransactionContext) -> Value {
                    flatMap(context: context)
                }
                @MainActor public static let shared = MyAtom()
            }

            extension MyAtom: SKValueAtom {
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }
}
