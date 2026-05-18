import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import StateKitMacrosPlugin

final class HookIntervalTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "HookInterval": HookIntervalMacro.self
    ]

    func testHookIntervalMacro() {
        assertMacroExpansion(
            """
            @HookInterval
            struct I { var intervalMs: Int; func tick() async {} }
            """,
            expandedSource: """
            struct I { var intervalMs: Int; func tick() async {} 
            }

            @MainActor
            func useI(intervalMs: Int) {
                StateKit.useEffect(updateStrategy: .preserved(by: intervalMs)) {
                    let instance = I(
                intervalMs: intervalMs
                )
                    let task = Task {
                        while !Task.isCancelled {
                            try? await Task.sleep(nanoseconds: UInt64(instance.intervalMs) * 1_000_000)
                            if !Task.isCancelled {
                                await instance.tick()
                            }
                        }
                    }
                    return {
                        task.cancel()
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
}
