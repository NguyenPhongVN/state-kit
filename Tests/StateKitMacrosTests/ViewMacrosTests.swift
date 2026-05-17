import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class ViewMacrosTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "HookView": HookViewMacro.self,
        "StateView": StateViewMacro.self,
        "AsyncView": AsyncViewMacro.self,
        "ObservableState": ObservableStateMacro.self
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

    func testObservableStateMacro() {
        assertMacroExpansion(
            """
            @ObservableState
            struct MyState {
                var count = 0
            }
            """,
            expandedSource: """
            struct MyState {
                var count = 0

                private let _observationRegistrar = ObservationRegistrar()

                nonisolated public func withObserver<V>(_ body: () -> V) -> V {
                    _observe {
                        body()
                    }
                }

                nonisolated private func _observe<V>(_ body: () -> V) -> V {
                    _observationRegistrar.withMutation(of: self, keyPath: \\.self) {
                        body()
                    }
                }
            }

            extension MyState: Observable {
            }
            """,
            macros: testMacros
        )
    }
}
