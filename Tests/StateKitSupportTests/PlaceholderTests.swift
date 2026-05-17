import Testing
import SwiftUI
@testable import StateKitSupport

@Suite("StateKitSupport — HState Binding Bridge")
@MainActor
struct HStateBindingBridgeTests {
    @Test("wrappedValue reads and writes through provided Binding")
    func wrappedValueBridgesBinding() {
        var source = "Initial"
        let binding = Binding(
            get: { source },
            set: { source = $0 }
        )

        let state = HState<String>(wrappedValue: binding)
        #expect(state.wrappedValue == "Initial")

        state.wrappedValue = "Updated"
        #expect(source == "Updated")
    }

    @Test("projectedValue writes update original source")
    func projectedValueBridgesBinding() {
        var source = 1
        let state = HState<Int>(wrappedValue: Binding(
            get: { source },
            set: { source = $0 }
        ))

        state.projectedValue.wrappedValue = 7
        #expect(source == 7)
    }
}
