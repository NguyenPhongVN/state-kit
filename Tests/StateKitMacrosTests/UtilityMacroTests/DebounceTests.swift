import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class DebounceTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "Debounce": DebounceMacro.self
    ]

    func testDebounceMacro() {
        assertMacroExpansion(
            "@Debounce(milliseconds: 100) func d() async {}",
            expandedSource: """
            func d() async {}

            @MainActor
            private var _dDebounceTask: Task<Void, Never>?

            @MainActor
            func dDebounced() {
                _dDebounceTask?.cancel()
                _dDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(100) * 1_000_000)
                    if !Task.isCancelled {
                        await d()
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
}
