import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Combine

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
            """
            @StateAtom
            struct MyAtom {
                func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
            }

            @MainActor extension MyAtom: SKStateAtom {
                typealias Value = Int
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: ["StateAtom": StateAtomMacro.self]
        )
    }

    func testValueAtomMacro() {
        assertMacroExpansion(
            """
            @ValueAtom
            struct MyAtom {
                func value(context: SKAtomTransactionContext) -> String { "" }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func value(context: SKAtomTransactionContext) -> String { "" }
            }

            @MainActor extension MyAtom: SKValueAtom {
                typealias Value = String
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testTaskAtomMacro() {
        assertMacroExpansion(
            """
            @TaskAtom
            struct MyAtom {
                func task(context: SKAtomTransactionContext) async -> Int { 0 }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func task(context: SKAtomTransactionContext) async -> Int { 0 }
            }

            @MainActor extension MyAtom: SKTaskAtom {
                typealias TaskSuccess = Int
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testThrowingTaskAtomMacro() {
        assertMacroExpansion(
            """
            @ThrowingTaskAtom
            struct MyAtom {
                func task(context: SKAtomTransactionContext) async throws -> Int { 0 }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func task(context: SKAtomTransactionContext) async throws -> Int { 0 }
            }

            @MainActor extension MyAtom: SKThrowingTaskAtom {
                typealias TaskSuccess = Int
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
            }

            @MainActor extension MyAtom: SKPublisherAtom {
                typealias PublisherOutput = Int
                typealias AtomPublisher = AnyPublisher<Int, Error>
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
            }

            @MainActor extension UserAtom: SKStateAtom {
                typealias Value = String
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
            }

            @MainActor extension UserSelector: SKValueAtom {
                typealias Value = String
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
            }

            @MainActor extension UserTask: SKTaskAtom {
                typealias TaskSuccess = Int
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

                @MainActor
                func defaultValue(context: SKAtomTransactionContext) -> Value {
                    Value()
                }
            }

            @MainActor extension MyReducer: SKStateAtom {
                typealias Value = Int
            }

            extension MyReducer: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testComputedMacro() {
        assertMacroExpansion(
            """
            @Computed
            struct MyAtom {
                func compute(context: SKAtomTransactionContext) -> Int { 0 }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func compute(context: SKAtomTransactionContext) -> Int { 0 }

                @MainActor func value(context: SKAtomTransactionContext) -> Value {
                    compute(context: context)
                }
            }

            @MainActor extension MyAtom: SKValueAtom {
                typealias Value = Int
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testSelectorAtomMacro() {
        assertMacroExpansion(
            """
            @SelectorAtom
            struct MyAtom {
                func select(context: SKAtomTransactionContext) -> Int { 0 }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func select(context: SKAtomTransactionContext) -> Int { 0 }

                @MainActor func value(context: SKAtomTransactionContext) -> Value {
                    select(context: context)
                }
            }

            @MainActor extension MyAtom: SKValueAtom {
                typealias Value = Int
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testFilteredAtomMacro() {
        assertMacroExpansion(
            """
            @FilteredAtom
            struct MyAtom {
                func source(context: SKAtomTransactionContext) -> [Int] { [] }
                func predicate(_ v: Int) -> Bool { true }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func source(context: SKAtomTransactionContext) -> [Int] { [] }
                @MainActor
                func predicate(_ v: Int) -> Bool { true }

                @MainActor func value(context: SKAtomTransactionContext) -> Value {
                    source(context: context).filter(predicate)
                }
            }

            @MainActor extension MyAtom: SKValueAtom {
                typealias Value = [Int]
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testMappedAtomMacro() {
        assertMacroExpansion(
            """
            @MappedAtom
            struct MyAtom {
                func source(context: SKAtomTransactionContext) -> Int { 0 }
                func transform(_ v: Int) -> String { "" }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func source(context: SKAtomTransactionContext) -> Int { 0 }
                @MainActor
                func transform(_ v: Int) -> String { "" }

                @MainActor func value(context: SKAtomTransactionContext) -> Value {
                    transform(source(context: context))
                }
            }

            @MainActor extension MyAtom: SKValueAtom {
                typealias Value = String
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testCombineAtomMacro() {
        assertMacroExpansion(
            """
            @CombineAtom
            struct MyAtom {
                func combine(context: SKAtomTransactionContext) -> Int { 0 }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func combine(context: SKAtomTransactionContext) -> Int { 0 }

                @MainActor func value(context: SKAtomTransactionContext) -> Value {
                    combine(context: context)
                }
            }

            @MainActor extension MyAtom: SKValueAtom {
                typealias Value = Int
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testDistinctAtomMacro() {
        assertMacroExpansion(
            """
            @DistinctAtom
            struct MyAtom {
                func source(context: SKAtomTransactionContext) -> Int { 0 }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func source(context: SKAtomTransactionContext) -> Int { 0 }

                @MainActor func value(context: SKAtomTransactionContext) -> Value {
                    source(context: context)
                }
            }

            @MainActor extension MyAtom: SKValueAtom {
                typealias Value = Int
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }

    func testFlatMapAtomMacro() {
        assertMacroExpansion(
            """
            @FlatMapAtom
            struct MyAtom {
                func flatMap(context: SKAtomTransactionContext) -> Int { 0 }
            }
            """,
            expandedSource: """
            struct MyAtom {
                @MainActor
                func flatMap(context: SKAtomTransactionContext) -> Int { 0 }

                @MainActor func value(context: SKAtomTransactionContext) -> Value {
                    flatMap(context: context)
                }
            }

            @MainActor extension MyAtom: SKValueAtom {
                typealias Value = Int
            }

            extension MyAtom: Hashable {
            }
            """,
            macros: testMacros
        )
    }
}
