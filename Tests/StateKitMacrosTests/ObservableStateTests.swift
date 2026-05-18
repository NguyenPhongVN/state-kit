import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class ObservableStateTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "ObservableState": ObservableStateMacro.self
    ]

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

    func testObservableStateClass() {
        assertMacroExpansion(
            """
            @ObservableState
            class MyState {
                var count = 0
            }
            """,
            expandedSource: """
            class MyState {
                @ObservationTracked
                var count = 0

                private let _observationRegistrar = ObservationRegistrar()
            }

            extension MyState: Observable {
            }
            """,
            macros: testMacros
        )
    }
}
