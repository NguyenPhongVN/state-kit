import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class ThrottleTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "Throttle": ThrottleMacro.self
    ]

    func testThrottleMacro() {
        assertMacroExpansion(
            "@Throttle(milliseconds: 100) func t() async {}",
            expandedSource: """
            func t() async {}

            @MainActor
            private var _tThrottleLastExec: Date = Date(timeIntervalSince1970: 0)

            @MainActor
            func tThrottled() {
                let now = Date()
                let interval = TimeInterval(100) / 1000.0

                if now.timeIntervalSince(_tThrottleLastExec) >= interval {
                    _tThrottleLastExec = now
                    Task {
                        await t()
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
}
